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

module "cni" {
  source = "../cni"
  cni    = "${var.cni}"
  k8s    = "${local.k8s}"
}

module "sc" {
  source = "../storageclass"
  sc     = "${var.sc}"
  k8s    = "${local.k8s}"
}

data "ignition_systemd_unit" "installer" {
  name    = "k8s_installer.service"
  enabled = true

  content = <<UNIT
[Unit]
Requires=network-online.target set-environment.service
After=set-environment.service
ConditionPathExists=!/opt/kubelet.conf
[Service]
SyslogIdentifier=install_k8s
RemainAfterExit=True
EnvironmentFile=/etc/environment
ExecStartPre=/usr/bin/mkdir -p /local-volumes /opt/bin /opt/cni/bin /etc/cni/net.d
ExecStartPre=/usr/bin/ln -s /etc/cni/net.d /opt/cni/net.d
ExecStartPre=/usr/bin/curl -f -L -f -o /opt/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$${KUBERNETES_VERSION}/bin/linux/amd64/kubectl
ExecStartPre=/usr/bin/chmod +x /opt/bin/kubectl
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
Requires=network-online.target
After=k8s_installer.service docker.service rkt-metadata.service containerd.service
StartLimitIntervalSec=0
[Service]
SyslogIdentifier=kubelet
EnvironmentFile=/etc/environment
Environment="RKT_GLOBAL_ARGS=--insecure-options=image"
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/opt/bootstrap-kubelet.conf --kubeconfig=/opt/kubelet.conf"
Environment="KUBELET_SYSTEM_PODS_ARGS=--pod-manifest-path=/opt/manifests --allow-privileged=true"
Environment="KUBELET_NETWORK_ARGS=--network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin"
Environment="KUBELET_DNS_ARGS=--cluster-dns=10.245.0.10 --cluster-domain=cluster.local"
Environment="KUBELET_AUTHZ_ARGS=--authorization-mode=AlwaysAllow --client-ca-file=/etc/ssl/k8s/ca.crt"
Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs"
Environment="KUBELET_CADVISOR_ARGS="
Environment="KUBELET_CERTIFICATE_ARGS=--rotate-certificates=true --cert-dir=/var/lib/kubelet/pki"
Environment="KUBELET_EXTRA_ARGS=--feature-gates=PersistentLocalVolumes=true,MountPropagation=true,VolumeScheduling=true"
Environment="RKT_RUN_ARGS=--volume local-volumes,kind=host,source=/local-volumes,readOnly=false,recursive=true --mount volume=local-volumes,target=/local-volumes --volume coreos-opt-kubernetes,kind=host,source=/opt,readOnly=false,recursive=true --mount volume=coreos-opt-kubernetes,target=/opt --volume coreos-ca-kubernetes,kind=host,source=/etc/ssl/k8s,readOnly=false,recursive=true --mount volume=coreos-ca-kubernetes,target=/etc/ssl/k8s --volume coreos-cni-kubernetes,kind=host,source=/etc/cni,readOnly=false,recursive=true --mount volume=coreos-cni-kubernetes,target=/etc/cni --volume resolv-conf,kind=host,source=/etc/resolv.conf --mount volume=resolv-conf,target=/etc/resolv.conf  ${module.cni.kubelet.rkt != "" ? module.cni.kubelet.rkt : ""}"
${module.cni.kubelet.service != "" ? module.cni.kubelet.service : ""}
ExecStart=/usr/lib64/coreos/kubelet-wrapper $KUBELET_KUBECONFIG_ARGS $KUBELET_SYSTEM_PODS_ARGS $KUBELET_NETWORK_ARGS $KUBELET_DNS_ARGS $KUBELET_AUTHZ_ARGS $KUBELET_CGROUP_ARGS $KUBELET_CADVISOR_ARGS $KUBELET_CERTIFICATE_ARGS $KUBELET_EXTRA_ARGS
Restart=always
RestartSec=1
[Install]
WantedBy=multi-user.target
UNIT
}

data "ignition_config" "ignition" {
  files = "${compact(concat(module.cni.manifests, module.sc.manifests))}"
  systemd = [
    "${data.ignition_systemd_unit.installer.id}",
    "${data.ignition_systemd_unit.kubelet.id}"
  ]
}
