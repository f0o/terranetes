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
  nodes = [for k, v in var.k8s.nodes : merge(v, map("ip", "${cidrhost(var.k8s.network.cidr, k + var.k8s.network.base + 1)}", "name", "terranetes-${k}"))]
  defaults = {
    dns  = "8.8.8.8"
    dhcp = true
    base = "${var.k8s.network.base != "" ? var.k8s.network.base : 50}"
    lb   = "${var.k8s.loadbalancer.enable ? cidrhost(var.k8s.network.cidr, var.k8s.network.base) : ""}"
    api  = "${var.k8s.loadbalancer.enable ? cidrhost(var.k8s.network.cidr, var.k8s.network.base) : element([for v in local.nodes : v.ip if contains(v.labels, "master")], 0)}"
  }
  network = "${merge(local.defaults, var.k8s.network)}"
}
