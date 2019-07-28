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

data "ignition_file" "etcd-pod" {
  count      = "${local.k8s.etcd.type == "pod" ? length(local.masters) : 0}"
  filesystem = "root"
  path       = "/opt/templates/manifests/01-etcd.json"
  mode       = 420

  content {
    content = "${templatefile("${path.module}/etcd.tmpl", merge(map("cluster", join(",", [for k, v in local.masters : "etcd-${v.name}=https://${v.ip}:2380" if k <= count.index]), "token", random_uuid.cluster-token.result, "state", "${count.index == 0 ? "new" : "existing"}"), local.k8s))}"
  }
}

resource "random_uuid" "cluster-token" {}

data "ignition_file" "etcd-cert" {
  count      = "${local.count}"
  filesystem = "root"
  path       = "/etc/etcd/etcd.crt"
  mode       = 420

  content {
    content = "${var.pki.etcd.certs[count.index]}"
  }
}

data "ignition_file" "etcd-key" {
  count      = "${local.count}"
  filesystem = "root"
  path       = "/etc/etcd/etcd.key"
  mode       = 420

  content {
    content = "${var.pki.etcd.keys[count.index]}"
  }
}