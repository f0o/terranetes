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

data "ignition_file" "cni" {
  filesystem = "root"
  path       = "/opt/post-deploy/01-cni.yaml"
  mode       = 420

  source {
    source = "${format(lookup(lookup(local.cni_types, var.k8s.cni.type), "url"), local.version)}"
  }
}

data "ignition_file" "extra" {
  count      = "${var.k8s.cni.extra && lookup(lookup(local.cni_types, var.k8s.cni.type), "extra") != "" ? 1 : 0}"
  filesystem = "root"
  path       = "/opt/post-deploy/01-cni-extra.yaml"
  mode       = 420

  source {
    source = "${format(lookup(lookup(local.cni_types, var.k8s.cni.type), "extra"), local.version)}"
  }
}