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

variable "pki" {
  description = "PKI Object - See PKI Module for Documentation"
}

locals {
  masters   = [for i in var.k8s.nodes : i if contains(i.labels, "master") == true]
  count     = "${var.k8s.etcd.type == "pod" ? length(local.masters) : length(var.k8s.etcd.nodes)}"
  discovery = "${var.k8s.etcd.discovery == "" ? "etcd.io" : var.k8s.etcd.discovery}"
  defaults = {
    image = "${var.k8s.etcd.image == "" ? "k8s.gcr.io/etcd:3.3.10" : var.k8s.etcd.image}"
  }
  k8s = "${merge(var.k8s, map("etcd", merge(var.k8s.etcd, local.defaults)))}"
  /*
    Calculate modifiers to return to the Kubernetes Module to alter parts of it's deployments.
    See outputs for more qualified Documentation of these entries.
  */
  inject = {
    installer = "${local.k8s.etcd.type == "pod" ? "ExecStartPre=/bin/cp /etc/ssl/ca.crt /etc/etcd/ca.crt" : ""}"
    alias = {
      master = [
        "${local.k8s.etcd.type == "pod" ? "etcd-$${HOSTNAME}" : ""}"
      ]
    }
    hosts = ""
    kubelet = {
      service = ""
      rkt     = ""
    }
  }
}