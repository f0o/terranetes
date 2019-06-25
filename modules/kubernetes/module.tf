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

data "ignition_systemd_unit" "installer" {
  count   = "${length(local.k8s.nodes)}"
  name    = "k8s_installer.service"
  enabled = true

  content = <<UNIT
[Unit]
Requires=network-online.target set-environment.service
After=set-environment.service
ConditionPathExists=!/opt/kubelet.conf
[Service]
SyslogIdentifier=k8s_installer
RemainAfterExit=True
EnvironmentFile=/etc/environment
ExecStartPre=/usr/bin/mkdir -p /local-volumes /opt/bin /opt/cni/bin /etc/cni/net.d /opt/manifests
ExecStartPre=/usr/bin/ln -s /etc/cni/net.d /opt/cni/net.d
ExecStartPre=/usr/bin/curl -f -L -f -o /opt/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$${KUBERNETES_VERSION}/bin/linux/amd64/kubectl
ExecStartPre=/usr/bin/chmod +x /opt/bin/kubectl
${contains(local.k8s.nodes[count.index].labels, "master") ? module.etcd.inject.installer : ""}
ExecStartPre=/bin/sh -c 'for i in /opt/templates/manifests/*.yaml; do echo "Parsing $i"; envsubst < $i > /opt/manifests/$(basename $i); done'
ExecStart=/bin/true
Restart=on-failure
RestartSec=10
TimeoutSec=0
[Install]
WantedBy=multi-user.target
UNIT
}

data "ignition_systemd_unit" "kubelet" {
  name = "kubelet.service"
  enabled = true

  content = <<UNIT
[Unit]
Description=Kubernetes Controller Manager
Requires=network-online.target k8s_installer.service
After=k8s_installer.service docker.service rkt-metadata.service containerd.service
StartLimitIntervalSec=0
[Service]
SyslogIdentifier=kubelet
EnvironmentFile=/etc/environment
Environment="RKT_GLOBAL_ARGS=--insecure-options=image"
Environment="KUBELET_KUBECONFIG_ARGS=--kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_SYSTEM_PODS_ARGS=--pod-manifest-path=/opt/manifests --allow-privileged=true"
Environment="KUBELET_NETWORK_ARGS=--network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin"
Environment="KUBELET_DNS_ARGS=--cluster-dns=10.245.0.10 --cluster-domain=cluster.local"
Environment="KUBELET_AUTHZ_ARGS=--authorization-mode=AlwaysAllow --client-ca-file=/etc/ssl/ca.crt"
Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs"
Environment="KUBELET_CADVISOR_ARGS="
Environment="KUBELET_CERTIFICATE_ARGS=--rotate-certificates=true --cert-dir=/var/lib/kubelet/pki"
Environment="KUBELET_EXTRA_ARGS=--feature-gates=PersistentLocalVolumes=true,VolumeScheduling=true"
Environment="RKT_RUN_ARGS=--volume local-volumes,kind=host,source=/local-volumes,readOnly=false,recursive=true --mount volume=local-volumes,target=/local-volumes --volume opt,kind=host,source=/opt,readOnly=false,recursive=true --mount volume=opt,target=/opt --volume ssl-kubelet,kind=host,source=/etc/ssl/k8s/kubelet,readOnly=false,recursive=true --mount volume=ssl-kubelet,target=/etc/ssl/k8s/kubelet --volume ca-kubelet,kind=host,source=/etc/ssl/ca.crt,readOnly=true --mount volume=ca-kubelet,target=/etc/ssl/ca.crt --volume cni,kind=host,source=/etc/cni,readOnly=false,recursive=true --mount volume=cni,target=/etc/cni --volume resolv-conf,kind=host,source=/etc/resolv.conf --mount volume=resolv-conf,target=/etc/resolv.conf ${module.cni.inject.kubelet.rkt}"
${module.cni.inject.kubelet.service}
ExecStart=/usr/lib64/coreos/kubelet-wrapper $KUBELET_KUBECONFIG_ARGS $KUBELET_SYSTEM_PODS_ARGS $KUBELET_NETWORK_ARGS $KUBELET_DNS_ARGS $KUBELET_AUTHZ_ARGS $KUBELET_CGROUP_ARGS $KUBELET_CADVISOR_ARGS $KUBELET_CERTIFICATE_ARGS $KUBELET_EXTRA_ARGS
Restart=always
RestartSec=1
[Install]
WantedBy=multi-user.target
UNIT
}

data "ignition_systemd_unit" "set-environment" {
  count   = "${length(local.k8s.nodes)}"
  name    = "set-environment.service"
  enabled = true

  content = <<UNIT
[Unit]
Requires=network-online.target
After=network-online.target
ConditionFirstBoot=True
[Service]
EnvironmentFile=/etc/environment
RemainAfterExit=True
ExecStartPre=/bin/sh -c "echo HOSTNAME=k8s-${count.index} | tee /etc/environment"
ExecStartPre=/bin/sh -c "echo HOSTNAME_BIOS=$(hostname) | tee -a /etc/environment"
ExecStartPre=/bin/sh -c "echo HOST_IP=$(ip a | grep en | tail -n 1 | cut -d / -f 1 | rev |  cut -d \  -f 1 | rev) | tee -a /etc/environment"
ExecStartPre=/bin/sh -c "echo KUBERNETES_VERSION=${local.k8s.version} | tee -a /etc/environment"
ExecStartPre=/bin/sh -c "echo KUBELET_IMAGE_TAG=${local.k8s.version} | tee -a /etc/environment"
ExecStartPre=/bin/sh -c "echo KUBELET_IMAGE_URL=${local.k8s.image} | tee -a /etc/environment"
ExecStartPre=/bin/sh -c "echo KUBELET_LABELS=${join(",", local.k8s.nodes[count.index].labels)} | tee -a /etc/environment"
ExecStart=/bin/echo started
[Install]
WantedBy=multi-user.target
UNIT
}

data "ignition_systemd_unit" "drainer" {
  name = "drainer.service"
  enabled = true

  content = <<UNIT
[Unit]
Description=Simple Service to Drain the current node and force migration of resources before shutdown
After=kubelet.service docker.service rkt-metadata.service containerd.service
[Service]
SyslogIdentifier=kubelet
EnvironmentFile=/etc/environment
Type=oneshot
RemainAfterExit=true
ExecStop=/opt/bin/kubectl --kubeconfig=/opt/kubelet.conf drain $HOSTNAME --ignore-daemonsets --force --grace-period=60
ExecStopPost=/opt/bin/kubectl --kubeconfig=/opt/kubelet.conf delete node $HOSTNAME
TimeoutStopSec=0
[Install]
WantedBy=kubelet.service
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

data "ignition_file" "api-cert" {
  count      = "${local.k8s.pki.type == "local" ? 1 : 0}"
  filesystem = "root"
  path       = "/etc/ssl/k8s/api/api.crt"
  mode       = 420

  content {
    content = "${local.pki.components.api[0]}"
  }
}

data "ignition_file" "api-key" {
  count      = "${local.k8s.pki.type == "local" ? 1 : 0}"
  filesystem = "root"
  path       = "/etc/ssl/k8s/api/api.key"
  mode       = 420

  content {
    content = "${local.pki.components.api[1]}"
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

data "ignition_file" "proxy-cert" {
  count      = "${local.k8s.pki.type == "local" ? 1 : 0}"
  filesystem = "root"
  path       = "/etc/ssl/k8s/proxy/proxy.crt"
  mode       = 420

  content {
    content = "${local.pki.components.proxy[0]}"
  }
}

data "ignition_file" "proxy-key" {
  count      = "${local.k8s.pki.type == "local" ? 1 : 0}"
  filesystem = "root"
  path       = "/etc/ssl/k8s/proxy/proxy.key"
  mode       = 420

  content {
    content = "${local.pki.components.proxy[1]}"
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

data "ignition_file" "kubelet-conf" {
  count      = "${length(local.k8s.nodes)}"
  filesystem = "root"
  path       = "/etc/kubernetes/kubelet.conf"
  mode       = 420

  content {
    content = "${templatefile("${path.module}/kubelet.tmpl", merge(local.k8s, map("index", count.index, "api", "192.168.192.1")))}"
  }
}

data "ignition_config" "ignition" {
  count = "${length(local.k8s.nodes)}"
  files = "${compact(concat(
    contains(local.k8s.nodes[count.index].labels, "master") ? concat(list( //Node is Master
      local.k8s.etcd.type == "pod" ? module.etcd.files[count.index][0] : "",
      local.k8s.etcd.type == "pod" ? module.etcd.files[count.index][1] : "",
      local.k8s.pki.type == "local" ? data.ignition_file.api-cert.0.id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.api-key.0.id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.controller-cert.0.id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.controller-key.0.id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.proxy-cert.0.id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.proxy-key.0.id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.scheduler-cert.0.id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.scheduler-key.0.id : "",
      ),
      module.sc.manifests, module.etcd.manifests
      ) : contains(local.k8s.nodes[count.index].labels, "compute") ? list( //Node is Compute
      ""
      ) : list( //Node is anything else
      ""
    ),
    list(
      local.k8s.pki.type == "local" ? data.ignition_file.kubelet-cert[count.index].id : "",
      local.k8s.pki.type == "local" ? data.ignition_file.kubelet-key[count.index].id : "",
      data.ignition_file.kubelet-conf[count.index].id,
    ),
    data.ignition_file.ca-cert.*.id, module.cni.manifests
  ))}"
  users = ["${data.ignition_user.core.id}"]
  systemd = [
    "${data.ignition_systemd_unit.set-environment[count.index].id}",
    "${data.ignition_systemd_unit.installer[count.index].id}",
    "${data.ignition_systemd_unit.kubelet.id}",
    "${data.ignition_systemd_unit.drainer.id}",
  ]
}
