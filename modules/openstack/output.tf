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

output "k8s" {
  value = "${local.k8s}"
}
output "pki" {
  value = "${module.k8s.pki}"
}

output "admin" {
  value = {
    kubeconfig = "${templatefile("${path.module}/../kubernetes/kubeconfig.tmpl", map("api", "${local.k8s.loadbalancer.enable == true ? openstack_networking_floatingip_v2.fip[0].address : local.k8s.network.api}", "user", "admin", "crt", "admin.crt", "key", "admin.key", "ca", "ca.crt"))}"
    cert       = "${module.k8s.pki.users.admin[0]}"
    key        = "${module.k8s.pki.users.admin[1]}"
    ca         = "${module.k8s.pki.ca.cert}"
  }
}