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

variable "k8s" {
  description = "Kubernetes Object"
  type = object({
    version = string,
    image   = string,
    pubkeys = list(string),
    nodes = list(object({
      type    = string,
      image   = string,
      labels  = list(string),
      version = string
    })),
    network = object({
      cidr     = string,
      upstream = string,
      dhcp     = bool,
      dns      = list(string),
      base     = string,
      fip      = bool,
      pool     = string,
    })
    etcd = object({
      type      = string,
      discovery = string,
      image     = string,
      nodes = list(object({
        type  = string,
        image = string
      }))
    }),
    cni = object({
      type    = string,
      version = string,
      extra   = bool
    }),
    storages = list(object({
      name   = string,
      type   = string,
      params = map(string)
    })),
    pki = object({
      type = string
    })
    loadbalancer = object({
      enable = bool
      type   = string
      specs  = object({})
    })
    ingress = object({
      enable = bool
      type   = string
      specs  = object({})
    })
  })
}

locals {
  defaults = {
    version       = "v${var.k8s.version}"
    version_short = "v${join(".", slice(split(".", var.k8s.version), 0, 2))}"
    image         = "${var.k8s.image != "" ? var.k8s.image : "docker://gcr.io/google-containers/hyperkube"}"
    network       = "${merge(var.k8s.network, module.network.network)}"
    nodes         = [for k, v in module.network.nodes : merge(v, map("version", "v${var.k8s.nodes[k].version == "" ? var.k8s.version : var.k8s.nodes[k].version}", "version_short", "v${join(".", slice(split(".", var.k8s.nodes[k].version == "" ? var.k8s.version : var.k8s.nodes[k].version), 0, 2))}"))]
  }
  pki       = "${module.pki.pki}"
  k8s       = "${merge(var.k8s, local.defaults)}"
  masters   = [for i in local.k8s.nodes : i if contains(i.labels, "master") == true]
  conmputes = [for i in local.k8s.nodes : i if contains(i.labels, "compute") == true]
  ingresses = [for i in local.k8s.nodes : i if contains(i.labels, "ingress") == true]
  counts = {
    master  = "${length(local.masters)}"
    compute = "${length(local.conmputes)}"
    ingress = "${length(local.ingresses)}"
  }
  config_mapping = [
    {
      short = "v1.14"
      key   = 0
    },
    {
      short = "v1.15"
      key   = 1
    }
  ]
  configs = [
    {
      kubelet = {
        KUBELET_KUBECONFIG_ARGS  = "--kubeconfig=/etc/kubernetes/kubelet.conf"
        KUBELET_SYSTEM_PODS_ARGS = "--pod-manifest-path=/opt/manifests --allow-privileged=true"
        KUBELET_NETWORK_ARGS     = "--network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin"
        KUBELET_DNS_ARGS         = "--cluster-dns=10.0.0.2 --cluster-domain=cluster.local"
        KUBELET_AUTHZ_ARGS       = "--authorization-mode=AlwaysAllow --client-ca-file=/etc/ssl/ca.crt"
        KUBELET_CGROUP_ARGS      = "--cgroup-driver=cgroupfs"
        KUBELET_CADVISOR_ARGS    = ""
        KUBELET_CERTIFICATE_ARGS = "--rotate-certificates=true --cert-dir=/var/lib/kubelet/pki --tls-cert-file=/etc/ssl/k8s/kubelet/kubelet.crt --tls-private-key-file=/etc/ssl/k8s/kubelet/kubelet.key"
        KUBELET_EXTRA_ARGS       = "--feature-gates=PersistentLocalVolumes=true,VolumeScheduling=true"
      }
    }
  ]
}