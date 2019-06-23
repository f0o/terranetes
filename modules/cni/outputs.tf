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

/*
  List of Manifests as `ignition_file.id` references
*/
output "manifests" {
  value = "${concat(list(data.ignition_file.cni.id), data.ignition_file.extra.*.id)}"
}

/*
  The Kubelet output is a unified way of providing feedback to the Kubernetes 
  Module to ensure certain hooks or modifications of kubelet (such as mount 
  points or cmd arguments) are met.
  `installer`   This denotes systemd entries to be added to the k8s installer
  `service`     This denotes systemd entries to be added to the kubelet service
  `rkt`         This denotes arguments passed to the kubelet rkt call
*/

output "kubelet" {
  value = {
    installer = "${local.kubelet_installer}"
    service   = "${local.kubelet_svc}"
    rkt       = "${local.kubelet_rkt}"
  }
}
