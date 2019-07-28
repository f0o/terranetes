/*
    This file is part of Terranetes (https://github.com/f0o/terranetes)
    Copyright (C) 2019  Daniel 'f0o' Preussker <f0o@devilcode.org>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

module "network" {
  source = "../network"
  k8s    = "${var.k8s}"
}

module "pki" {
  source = "../pki"
  k8s    = "${local.k8s}"
}

module "etcd" {
  source = "../etcd"
  k8s    = "${local.k8s}"
  pki    = "${local.pki}"
}

module "cni" {
  source = "../cni"
  k8s    = "${local.k8s}"
}

module "sc" {
  source = "../storageclass"
  k8s    = "${local.k8s}"
}

module "ingress" {
  source = "../ingress"
  k8s    = "${local.k8s}"
}

data "ignition_systemd_unit" "installer" {
  count   = "${length(local.k8s.nodes)}"
  name    = "k8s_installer.service"
  enabled = true

  content = <<UNIT
[Unit]
Requires=network-online.target set-environment.service
After=set-environment.service
ConditionPathExists=!/etc/kubernetes/.installed
[Service]
SyslogIdentifier=k8s_installer
RemainAfterExit=True
EnvironmentFile=/etc/environment
ExecStartPre=/bin/sh -c 'mkdir -p /local-volumes /opt/bin /opt/cni/bin /etc/cni/net.d /opt/manifests && if [ ! -L /opt/cni/net.d ]; then ln -s /etc/cni/net.d /opt/cni/net.d; fi'
ExecStartPre=/bin/sh -c 'curl -f -L -f -o /opt/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$${KUBERNETES_VERSION}/bin/linux/amd64/kubectl && chmod +x /opt/bin/kubectl'
${contains(local.k8s.nodes[count.index].labels, "master") ? module.etcd.inject.installer : ""}
ExecStart=/usr/bin/touch /etc/kubernetes/.installed
Restart=on-failure
RestartSec=10
TimeoutSec=0
[Install]
WantedBy=multi-user.target
UNIT
}

data "ignition_systemd_unit" "deployer" {
  name = "k8s_deployer.service"
  enabled = true

  content = <<UNIT
[Unit]
Requires=network-online.target set-environment.service k8s_installer.service kubelet.service
ConditionPathExists=/opt/tmp/deployer.conf
[Service]
SyslogIdentifier=k8s_deployer
RemainAfterExit=True
EnvironmentFile=/etc/environment
ExecStart=/bin/sh -c '( if [ ! -d /opt/templates/manifests ]; then exit 0; fi; for i in /opt/templates/manifests/*.*; do echo "Parsing $i"; envsubst < $i | sed "s/%/$/g" > /opt/manifests/$(basename $i); done ) && ( if [ ! -d /opt/templates/post-deploy ]; then exit 0; fi; for i in /opt/templates/post-deploy/*.*; do echo "Parsing $i"; envsubst < $i > /opt/post-deploy/$(basename $i); done ) && ( if [ ! -d /opt/post-deploy ] || [ ! -f /opt/tmp/deployer.conf ]; then exit 0; else while [ "$(curl -k https://${local.k8s.network.api}:6443/healthz)" != "ok" ]; do sleep 10; done; sleep 30; for i in /opt/post-deploy/*.*; do /opt/bin/kubectl --kubeconfig /opt/tmp/deployer.conf apply -f $i || exit 2; done && rm -r /opt/tmp; fi )'
Restart=on-failure
RestartSec=10
TimeoutSec=0
[Install]
WantedBy=multi-user.target
UNIT
}

data "ignition_systemd_unit" "kubelet" {
  name    = "kubelet.service"
  enabled = true

  content = <<UNIT
[Unit]
Description=Kubernetes Controller Manager
Requires=network-online.target
After=k8s_installer.service docker.service rkt-metadata.service containerd.service
StartLimitIntervalSec=0
[Service]
SyslogIdentifier=kubelet
EnvironmentFile=/etc/environment
Environment="RKT_GLOBAL_ARGS=--insecure-options=image"
Environment="KUBELET_KUBECONFIG_ARGS=--kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_SYSTEM_PODS_ARGS=--pod-manifest-path=/opt/manifests --allow-privileged=true"
Environment="KUBELET_NETWORK_ARGS=--network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin"
Environment="KUBELET_DNS_ARGS=--cluster-dns=10.0.0.2 --cluster-domain=cluster.local"
Environment="KUBELET_AUTHZ_ARGS=--authorization-mode=AlwaysAllow --client-ca-file=/etc/ssl/ca.crt"
Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs"
Environment="KUBELET_CADVISOR_ARGS="
Environment="KUBELET_CERTIFICATE_ARGS=--rotate-certificates=true --cert-dir=/var/lib/kubelet/pki --tls-cert-file=/etc/ssl/k8s/kubelet/kubelet.crt --tls-private-key-file=/etc/ssl/k8s/kubelet/kubelet.key"
Environment="KUBELET_EXTRA_ARGS=--feature-gates=PersistentLocalVolumes=true,VolumeScheduling=true"
Environment="RKT_RUN_ARGS=--volume local-volumes,kind=host,source=/local-volumes,readOnly=false,recursive=true --mount volume=local-volumes,target=/local-volumes --volume opt,kind=host,source=/opt,readOnly=false,recursive=true --mount volume=opt,target=/opt --volume ssl-kubelet,kind=host,source=/etc/ssl/k8s/kubelet,readOnly=false,recursive=true --mount volume=ssl-kubelet,target=/etc/ssl/k8s/kubelet --volume ca-kubelet,kind=host,source=/etc/ssl/ca.crt,readOnly=true --mount volume=ca-kubelet,target=/etc/ssl/ca.crt --volume cni,kind=host,source=/etc/cni,readOnly=false,recursive=true --mount volume=cni,target=/etc/cni --volume resolv-conf,kind=host,source=/etc/resolv.conf --mount volume=resolv-conf,target=/etc/resolv.conf ${module.cni.inject.kubelet.rkt}"
${module.cni.inject.kubelet.service}
ExecStart=/usr/lib64/coreos/kubelet-wrapper $KUBELET_LABELS_ARGS $KUBELET_KUBECONFIG_ARGS $KUBELET_SYSTEM_PODS_ARGS $KUBELET_NETWORK_ARGS $KUBELET_DNS_ARGS $KUBELET_AUTHZ_ARGS $KUBELET_CGROUP_ARGS $KUBELET_CADVISOR_ARGS $KUBELET_CERTIFICATE_ARGS $KUBELET_EXTRA_ARGS
Restart=always
RestartSec=1
[Install]
WantedBy=multi-user.target
UNIT
}

data "ignition_systemd_unit" "set-environment" {
  count = "${length(local.k8s.nodes)}"
  name = "set-environment.service"
  enabled = true

  content = <<UNIT
[Unit]
Requires=network-online.target
After=network-online.target
ConditionFirstBoot=True
[Service]
EnvironmentFile=/etc/environment
RemainAfterExit=True
ExecStartPre=/bin/sh -c "echo HOSTNAME_BIOS=$(hostname) | tee /etc/environment"
ExecStartPre=/bin/sh -c "echo HOSTNAME_CLOUD=${local.k8s.nodes[count.index].name} | tee -a /etc/environment"
ExecStartPre=/bin/sh -c "echo HOST_IP=$(ip a | grep en | tail -n 1 | cut -d / -f 1 | rev |  cut -d \  -f 1 | rev) | tee -a /etc/environment"
ExecStartPre=/bin/sh -c "echo HOSTNAME=$${HOST_IP} | tee -a /etc/environment"
ExecStartPre=/usr/bin/hostnamectl set-hostname $${HOST_IP}
ExecStartPre=/bin/sh -c "echo KUBERNETES_VERSION=${local.k8s.nodes[count.index].version != "" ? local.k8s.nodes[count.index].version : local.k8s.version} | tee -a /etc/environment"
ExecStartPre=/bin/sh -c "echo KUBELET_IMAGE_TAG=$${KUBERNETES_VERSION} | tee -a /etc/environment"
ExecStartPre=/bin/sh -c "echo KUBELET_IMAGE_URL=${local.k8s.image} | tee -a /etc/environment"
ExecStartPre=/bin/sh -c "echo KUBELET_LABELS=${join(",", local.k8s.nodes[count.index].labels)} | tee -a /etc/environment"
ExecStartPre=/bin/sh -c "echo KUBELET_LABELS_ARGS=--node-labels=\\\"${join(",", [for i in local.k8s.nodes[count.index].labels : "node-role.kubernetes.io/${i}=true"])}\\\" | tee -a /etc/environment"
ExecStartPre=/bin/sh -c "echo $${HOST_IP} $${HOSTNAME} ${join(" ", [for i in local.k8s.nodes[count.index].labels : join(" ", lookup(module.etcd.inject.alias, i, []))])} | tee -a /etc/hosts"
ExecStartPre=/bin/sh -c "for i in ${module.cni.inject.hosts} ${module.etcd.inject.hosts} ${module.pki.inject.hosts} ${module.sc.inject.hosts}; do echo $i; done | tee -a /etc/hosts"
ExecStart=/bin/echo started
[Install]
WantedBy=multi-user.target
UNIT
}

data "ignition_user" "core" {
  name                = "core"
  ssh_authorized_keys = "${local.k8s.pubkeys}"
}

data "ignition_file" "kubelet-cert" {
  count      = "${local.k8s.pki.type == "local" ? length(var.k8s.nodes) : 0}"
  filesystem = "root"
  path       = "/etc/ssl/k8s/kubelet/kubelet.crt"
  mode       = 420

  content {
    content = "${local.pki.k8s.certs[count.index]}"
  }
}

data "ignition_file" "kubelet-key" {
  count      = "${local.k8s.pki.type == "local" ? length(var.k8s.nodes) : 0}"
  filesystem = "root"
  path       = "/etc/ssl/k8s/kubelet/kubelet.key"
  mode       = 420

  content {
    content = "${local.pki.k8s.keys[count.index]}"
  }
}

data "ignition_file" "ca-cert" {
  count      = "${local.k8s.pki.type == "local" ? 1 : 0}"
  filesystem = "root"
  path       = "/etc/ssl/ca.crt"
  mode       = 420

  content {
    content = "${local.pki.ca.cert}"
  }
}

data "ignition_file" "ca-key" {
  count      = "${local.k8s.pki.type == "local" ? 1 : 0}"
  filesystem = "root"
  path       = "/etc/ssl/ca.key"
  mode       = 420

  content {
    content = "${local.pki.ca.key}"
  }
}

data "ignition_file" "api-cert" {
  count      = "${local.k8s.pki.type == "local" ? "${local.counts.master}" : 0}"
  filesystem = "root"
  path       = "/etc/ssl/k8s/api/api.crt"
  mode       = 420

  content {
    content = "${local.pki.components.api[0][count.index]}"
  }
}

data "ignition_file" "api-key" {
  count      = "${local.k8s.pki.type == "local" ? "${local.counts.master}" : 0}"
  filesystem = "root"
  path       = "/etc/ssl/k8s/api/api.key"
  mode       = 420

  content {
    content = "${local.pki.components.api[1][count.index]}"
  }
}

data "ignition_file" "controller-cert" {
  count      = "${local.k8s.pki.type == "local" ? 1 : 0}"
  filesystem = "root"
  path       = "/etc/ssl/k8s/controller/controller.crt"
  mode       = 420

  content {
    content = "${local.pki.components.controller[0]}"
  }
}

data "ignition_file" "controller-key" {
  count      = "${local.k8s.pki.type == "local" ? 1 : 0}"
  filesystem = "root"
  path       = "/etc/ssl/k8s/controller/controller.key"
  mode       = 420

  content {
    content = "${local.pki.components.controller[1]}"
  }
}

data "ignition_file" "scheduler-cert" {
  count      = "${local.k8s.pki.type == "local" ? 1 : 0}"
  filesystem = "root"
  path       = "/etc/ssl/k8s/scheduler/scheduler.crt"
  mode       = 420

  content {
    content = "${local.pki.components.scheduler[0]}"
  }
}

data "ignition_file" "scheduler-key" {
  count      = "${local.k8s.pki.type == "local" ? 1 : 0}"
  filesystem = "root"
  path       = "/etc/ssl/k8s/scheduler/scheduler.key"
  mode       = 420

  content {
    content = "${local.pki.components.scheduler[1]}"
  }
}

data "ignition_file" "sa-cert" {
  count      = "${local.k8s.pki.type == "local" ? 1 : 0}"
  filesystem = "root"
  path       = "/etc/ssl/k8s/sa/sa.crt"
  mode       = 420

  content {
    content = "${local.pki.components.sa[0]}"
  }
}

data "ignition_file" "sa-key" {
  count      = "${local.k8s.pki.type == "local" ? 1 : 0}"
  filesystem = "root"
  path       = "/etc/ssl/k8s/sa/sa.key"
  mode       = 420

  content {
    content = "${local.pki.components.sa[1]}"
  }
}

data "ignition_file" "deployer-cert" {
  count      = "${local.k8s.pki.type == "local" ? 1 : 0}"
  filesystem = "root"
  path       = "/opt/tmp/deployer.crt"
  mode       = 420

  content {
    content = "${local.pki.users.deployer[0]}"
  }
}

data "ignition_file" "deployer-key" {
  count      = "${local.k8s.pki.type == "local" ? 1 : 0}"
  filesystem = "root"
  path       = "/opt/tmp/deployer.key"
  mode       = 420

  content {
    content = "${local.pki.users.deployer[1]}"
  }
}

data "ignition_file" "deployer-conf" {
  filesystem = "root"
  path       = "/opt/tmp/deployer.conf"
  mode       = 420

  content {
    content = "${templatefile("${path.module}/kubeconfig.tmpl", map("api", "${local.k8s.network.api}", "user", "k8s-deployer", "crt", "/opt/tmp/deployer.crt", "key", "/opt/tmp/deployer.key"))}"
  }
}

data "ignition_file" "kubelet-conf" {
  count      = "${length(local.k8s.nodes)}"
  filesystem = "root"
  path       = "/etc/kubernetes/kubelet.conf"
  mode       = 420

  content {
    content = "${templatefile("${path.module}/kubeconfig.tmpl", map("api", "${local.k8s.network.api}", "user", "system:node-${local.k8s.nodes[count.index].name}", "crt", "/etc/ssl/k8s/kubelet/kubelet.crt", "key", "/etc/ssl/k8s/kubelet/kubelet.key"))}"
  }
}

data "ignition_file" "controller-conf" {
  filesystem = "root"
  path       = "/etc/kubernetes/kube-controller-manager.conf"
  mode       = 420

  content {
    content = "${templatefile("${path.module}/kubeconfig.tmpl", map("api", "${local.k8s.network.api}", "user", "system:kube-controller-manager", "crt", "/etc/ssl/k8s/controller/controller.crt", "key", "/etc/ssl/k8s/controller/controller.key"))}"
  }
}

data "ignition_file" "scheduler-conf" {
  filesystem = "root"
  path       = "/etc/kubernetes/kube-scheduler.conf"
  mode       = 420

  content {
    content = "${templatefile("${path.module}/kubeconfig.tmpl", map("api", "${local.k8s.network.api}", "user", "system:kube-scheduler", "crt", "/etc/ssl/k8s/scheduler/scheduler.crt", "key", "/etc/ssl/k8s/scheduler/scheduler.key"))}"
  }
}

data "ignition_file" "kube-apiserver" {
  filesystem = "root"
  path       = "/opt/templates/manifests/02-kube-apiserver.json"
  mode       = 420

  content {
    content = "${templatefile("${path.module}/kube-apiserver.tmpl", merge(local.k8s, map("masters", local.masters)))}"
  }
}

data "ignition_file" "kube-controller-manager" {
  filesystem = "root"
  path       = "/opt/templates/manifests/03-kube-controller-manager.json"
  mode       = 420

  content {
    content = "${templatefile("${path.module}/kube-controller-manager.tmpl", merge(local.k8s, map("masters", local.masters)))}"
  }
}

data "ignition_file" "kube-scheduler" {
  filesystem = "root"
  path       = "/opt/templates/manifests/04-kube-scheduler.json"
  mode       = 420

  content {
    content = "${templatefile("${path.module}/kube-scheduler.tmpl", merge(local.k8s, map("masters", local.masters)))}"
  }
}

data "ignition_file" "kube-proxy" {
  filesystem = "root"
  path       = "/opt/templates/post-deploy/01-kube-proxy.json"
  mode       = 420

  content {
    content = "${templatefile("${path.module}/kube-proxy.tmpl", merge(local.k8s, map("key", replace(local.pki.components.proxy[1], "\n", "\\n"), "cert", replace(local.pki.components.proxy[0], "\n", "\\n"))))}"
  }
}

data "ignition_file" "coredns" {
  filesystem = "root"
  path       = "/opt/templates/post-deploy/05-coredns.json"
  mode       = 420

  content {
    content = "${file("${path.module}/coredns.tmpl")}"
  }
}

data "ignition_file" "uo-10" {
  filesystem = "root"
  path       = "/opt/templates/post-deploy/10-uo.yaml"
  mode       = 420

  source {
    source = "https://raw.githubusercontent.com/coreos/container-linux-update-operator/master/examples/deploy/00-namespace.yaml"
  }
}

data "ignition_file" "uo-11" {
  filesystem = "root"
  path       = "/opt/templates/post-deploy/11-uo.yaml"
  mode       = 420

  source {
    source = "https://raw.githubusercontent.com/coreos/container-linux-update-operator/master/examples/deploy/rbac/cluster-role.yaml"
  }
}

data "ignition_file" "uo-12" {
  filesystem = "root"
  path       = "/opt/templates/post-deploy/12-uo.yaml"
  mode       = 420

  source {
    source = "https://raw.githubusercontent.com/coreos/container-linux-update-operator/master/examples/deploy/rbac/cluster-role-binding.yaml"
  }
}

data "ignition_file" "uo-13" {
  filesystem = "root"
  path       = "/opt/templates/post-deploy/13-uo.yaml"
  mode       = 420

  source {
    source = "https://raw.githubusercontent.com/coreos/container-linux-update-operator/master/examples/deploy/update-agent.yaml"
  }
}

data "ignition_file" "uo-14" {
  filesystem = "root"
  path       = "/opt/templates/post-deploy/14-uo.yaml"
  mode       = 420

  source {
    source = "https://raw.githubusercontent.com/coreos/container-linux-update-operator/master/examples/deploy/update-operator.yaml"
  }
}

data "ignition_config" "ignition" {
  count = "${length(local.k8s.nodes)}"
  files = "${compact(concat(
    contains(local.k8s.nodes[count.index].labels, "master") ? concat(list( //Node is Master
      local.k8s.etcd.type == "pod" ? module.etcd.manifests[element([for k, v in local.masters : k if v.ip == local.k8s.nodes[count.index].ip], 0)] : "",
      local.k8s.etcd.type == "pod" ? module.etcd.files[element([for k, v in local.masters : k if v.ip == local.k8s.nodes[count.index].ip], 0)][0] : "",
      local.k8s.etcd.type == "pod" ? module.etcd.files[element([for k, v in local.masters : k if v.ip == local.k8s.nodes[count.index].ip], 0)][1] : "",
      local.k8s.pki.type == "local" ? data.ignition_file.api-cert[element([for k, v in local.masters : k if v.ip == local.k8s.nodes[count.index].ip], 0)].id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.api-key[element([for k, v in local.masters : k if v.ip == local.k8s.nodes[count.index].ip], 0)].id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.controller-cert[0].id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.controller-key[0].id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.sa-cert[0].id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.sa-key[0].id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.scheduler-cert[0].id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.scheduler-key[0].id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.deployer-cert[0].id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.deployer-key[0].id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.ca-key[0].id : "",
      data.ignition_file.kube-apiserver.id,
      data.ignition_file.kube-controller-manager.id,
      data.ignition_file.kube-scheduler.id,
      data.ignition_file.deployer-conf.id,
      data.ignition_file.controller-conf.id,
      data.ignition_file.scheduler-conf.id,
      data.ignition_file.kube-proxy.id,
      data.ignition_file.coredns.id,
      data.ignition_file.uo-10.id,
      data.ignition_file.uo-11.id,
      data.ignition_file.uo-12.id,
      data.ignition_file.uo-13.id,
      data.ignition_file.uo-14.id,
      ),
      module.sc.manifests, module.cni.manifests
      ) : contains(local.k8s.nodes[count.index].labels, "ingress") ? concat(list( //Node is Ingress
      local.k8s.pki.type == "local" ? data.ignition_file.deployer-cert[0].id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.deployer-key[0].id : "",
      data.ignition_file.deployer-conf.id,
      ),
      module.ingress.manifests
      ) : list( //Node is anything else
      ""
    ),
    list(
      local.k8s.pki.type == "local" ? data.ignition_file.kubelet-cert[count.index].id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.kubelet-key[count.index].id : "",
      data.ignition_file.kubelet-conf[count.index].id,
    ),
    data.ignition_file.ca-cert.*.id
  ))}"
  users = ["${data.ignition_user.core.id}"]
  systemd = [
    "${data.ignition_systemd_unit.set-environment[count.index].id}",
    "${data.ignition_systemd_unit.installer[count.index].id}",
    "${data.ignition_systemd_unit.deployer.id}",
    "${data.ignition_systemd_unit.kubelet.id}",
  ]
}
