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

output "pki" {
  value = {
    ca = {
      cert = "${tls_self_signed_cert.ca.0.cert_pem}"
      key  = "${tls_private_key.ca.0.private_key_pem}"
    }
    etcd = {
      certs = "${tls_locally_signed_cert.etcd.*.cert_pem}"
      keys  = "${tls_private_key.etcd.*.private_key_pem}"
    }
    k8s = {
      certs = "${tls_locally_signed_cert.k8s.*.cert_pem}"
      keys  = "${tls_private_key.k8s.*.private_key_pem}"
    }
    components = {
      api        = ["${tls_locally_signed_cert.api.*.cert_pem}", "${tls_private_key.api.*.private_key_pem}"]
      proxy      = ["${tls_locally_signed_cert.proxy.0.cert_pem}", "${tls_private_key.proxy.0.private_key_pem}"]
      scheduler  = ["${tls_locally_signed_cert.scheduler.0.cert_pem}", "${tls_private_key.scheduler.0.private_key_pem}"]
      controller = ["${tls_locally_signed_cert.controller.0.cert_pem}", "${tls_private_key.controller.0.private_key_pem}"]
      sa         = ["${tls_locally_signed_cert.sa.0.cert_pem}", "${tls_private_key.sa.0.private_key_pem}"]
    }
    users = {
      deployer = ["${tls_locally_signed_cert.deployer.0.cert_pem}", "${tls_private_key.deployer.0.private_key_pem}"]
      admin    = ["${tls_locally_signed_cert.admin.0.cert_pem}", "${tls_private_key.admin.0.private_key_pem}"]
    }
  }
}

output "inject" {
  value = "${local.inject}"
}
