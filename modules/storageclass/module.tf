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

data "ignition_file" "sc" {
  count      = "${length(var.k8s.storages)}"
  filesystem = "root"
  path       = "/opt/post-deploy/02-sc-${lookup(var.k8s.storages[count.index], "type")}-${count.index}.yaml"
  mode       = 420

  content {
    content = "${templatefile("${path.module}/${lookup(var.k8s.storages[count.index], "type")}.tmpl", var.k8s.storages[count.index])}"
  }
}