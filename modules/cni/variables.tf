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
  description = "Kubernetes Object - See Kubernetes Module for Documentation"
}

locals {
  /*
    Calculate modifiers to return to the Kubernetes Module to alter parts of it's deployments.
    See outputs for more qualified Documentation of these entries.
  */
  version = "${var.k8s.cni.version != "latest" ? var.k8s.cni.version : lookup(lookup(local.cni_types, var.k8s.cni.type), "version")}"
  inject = {
    installer = ""
    alias     = {}
    hosts     = ""
    kubelet = {
      service = "${var.k8s.cni.type == "canal" || var.k8s.cni.type == "calico" || var.k8s.cni.type == "calico-typha" ? "ExecStartPre=-/usr/bin/mkdir -p /var/lib/calico" : ""}"
      rkt     = "${var.k8s.cni.type == "canal" || var.k8s.cni.type == "calico" || var.k8s.cni.type == "calico-typha" ? "--volume calico,kind=host,source=/var/lib/calico,readOnly=false,recursive=true --mount volume=calico,target=/var/lib/calico" : ""}"
    }
  }
  cni_types = {
    canal = {
      version = "3.7"
      url     = "https://docs.projectcalico.org/v%s/manifests/canal.yaml"
      extra   = ""
    }
    calico = {
      version = "3.7"
      url     = "https://docs.projectcalico.org/v%s/manifests/calico.yaml"
      extra   = ""
    }
    calico-typha = {
      version = "3.7"
      url     = "https://docs.projectcalico.org/v%s/manifests/calico-typha.yaml"
      extra   = ""
    }
    weavenet = {
      version = "${var.k8s.version_short}"
      url     = "https://cloud.weave.works/k8s/%s/net.yaml"
      extra   = "https://cloud.weave.works/k8s/%s/scope.yaml"
    }
  }
}