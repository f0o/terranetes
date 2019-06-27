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
      type   = string,
      image  = string,
      labels = list(string)
    })),
    network = object({
      cidr     = string,
      upstream = string,
      dhcp     = string,
      dns      = string,
      base     = string
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
  })
}

locals {
  defaults = {
    version       = "v${var.k8s.version}"
    version_short = "v${join("", slice(split(".", var.k8s.version), 0, 1))}"
    image         = "${var.k8s.image != "" ? var.k8s.image : "docker://gcr.io/google-containers/hyperkube"}"
    network       = "${merge(var.k8s.network, local.network_default)}"
    nodes         = "${module.network.nodes}"
  }
  network_default = {
    base = "${var.k8s.network.base != "" ? var.k8s.network.base : 50}"
  }
  pki = "${module.pki.pki}"
  k8s = "${merge(var.k8s, local.defaults)}"
  counts = {
    master  = "${length([for i in var.k8s.nodes : i if contains(i.labels, "master") == true])}"
    compute = "${length([for i in var.k8s.nodes : i if contains(i.labels, "compute") == true])}"
    ingress = "${length([for i in var.k8s.nodes : i if contains(i.labels, "ingress") == true])}"
  }
}