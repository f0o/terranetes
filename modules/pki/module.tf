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

resource "tls_private_key" "ca" {
  count       = "${var.k8s.pki.type == "local" ? 1 : 0}"
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "ca" {
  count           = "${var.k8s.pki.type == "local" ? 1 : 0}"
  key_algorithm   = "ECDSA"
  private_key_pem = "${tls_private_key.ca.0.private_key_pem}"

  subject {
    common_name  = "Certificate Authority"
    organization = "Terranetes"
  }

  is_ca_certificate     = true
  validity_period_hours = 72
  early_renewal_hours   = 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
    "cert_signing",
    "crl_signing",
    "oscp_signing",
    "any_extended",
  ]
}

resource "tls_private_key" "etcd" {
  count       = "${var.k8s.pki.type == "local" ? local.counts.etcd : 0}"
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "etcd" {
  count           = "${var.k8s.pki.type == "local" ? local.counts.etcd : 0}"
  key_algorithm   = "ECDSA"
  private_key_pem = "${tls_private_key.etcd.*.private_key_pem[count.index]}"
  ip_addresses    = ["${var.k8s.etcd.type == "pod" ? "${local.masters[count.index].ip}" : ""}"]
  dns_names       = ["etcd-k8s-${count.index}"]

  subject {
    common_name  = "etcd-k8s-${count.index}"
    organization = "ETCd"
  }
}

resource "tls_locally_signed_cert" "etcd" {
  count              = "${var.k8s.pki.type == "local" ? local.counts.etcd : 0}"
  ca_key_algorithm   = "ECDSA"
  ca_private_key_pem = "${tls_private_key.ca.0.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.0.cert_pem}"
  cert_request_pem   = "${tls_cert_request.etcd.*.cert_request_pem[count.index]}"

  validity_period_hours = 72
  early_renewal_hours   = 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

resource "tls_private_key" "k8s" {
  count       = "${var.k8s.pki.type == "local" ? local.counts.k8s : 0}"
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "k8s" {
  count           = "${var.k8s.pki.type == "local" ? local.counts.k8s : 0}"
  key_algorithm   = "ECDSA"
  private_key_pem = "${tls_private_key.k8s.*.private_key_pem[count.index]}"

  subject {
    common_name  = "system:node:${count.index + 1}"
    organization = "Kubernetes"
  }
}

resource "tls_locally_signed_cert" "k8s" {
  count              = "${var.k8s.pki.type == "local" ? local.counts.k8s : 0}"
  ca_key_algorithm   = "ECDSA"
  ca_private_key_pem = "${tls_private_key.ca.0.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.0.cert_pem}"
  cert_request_pem   = "${tls_cert_request.k8s.*.cert_request_pem[count.index]}"

  validity_period_hours = 72
  early_renewal_hours   = 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

resource "tls_private_key" "api" {
  count       = "${var.k8s.pki.type == "local" ? 1 : 0}"
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "api" {
  count           = "${var.k8s.pki.type == "local" ? 1 : 0}"
  key_algorithm   = "ECDSA"
  private_key_pem = "${tls_private_key.api.0.private_key_pem}"

  subject {
    common_name  = "kubernetes"
    organization = "Kubernetes"
  }
}

resource "tls_locally_signed_cert" "api" {
  count              = "${var.k8s.pki.type == "local" ? 1 : 0}"
  ca_key_algorithm   = "ECDSA"
  ca_private_key_pem = "${tls_private_key.ca.0.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.0.cert_pem}"
  cert_request_pem   = "${tls_cert_request.api.0.cert_request_pem}"

  validity_period_hours = 72
  early_renewal_hours   = 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

resource "tls_private_key" "proxy" {
  count       = "${var.k8s.pki.type == "local" ? 1 : 0}"
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "proxy" {
  count           = "${var.k8s.pki.type == "local" ? 1 : 0}"
  key_algorithm   = "ECDSA"
  private_key_pem = "${tls_private_key.proxy.0.private_key_pem}"

  subject {
    common_name  = "system:kube-proxy"
    organization = "Kubernetes"
  }
}

resource "tls_locally_signed_cert" "proxy" {
  count              = "${var.k8s.pki.type == "local" ? 1 : 0}"
  ca_key_algorithm   = "ECDSA"
  ca_private_key_pem = "${tls_private_key.ca.0.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.0.cert_pem}"
  cert_request_pem   = "${tls_cert_request.proxy.0.cert_request_pem}"

  validity_period_hours = 72
  early_renewal_hours   = 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

resource "tls_private_key" "scheduler" {
  count       = "${var.k8s.pki.type == "local" ? 1 : 0}"
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "scheduler" {
  count           = "${var.k8s.pki.type == "local" ? 1 : 0}"
  key_algorithm   = "ECDSA"
  private_key_pem = "${tls_private_key.scheduler.0.private_key_pem}"

  subject {
    common_name  = "system:kube-scheduler"
    organization = "Kubernetes"
  }
}

resource "tls_locally_signed_cert" "scheduler" {
  count              = "${var.k8s.pki.type == "local" ? 1 : 0}"
  ca_key_algorithm   = "ECDSA"
  ca_private_key_pem = "${tls_private_key.ca.0.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.0.cert_pem}"
  cert_request_pem   = "${tls_cert_request.scheduler.0.cert_request_pem}"

  validity_period_hours = 72
  early_renewal_hours   = 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

resource "tls_private_key" "controller" {
  count       = "${var.k8s.pki.type == "local" ? 1 : 0}"
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "controller" {
  count           = "${var.k8s.pki.type == "local" ? 1 : 0}"
  key_algorithm   = "ECDSA"
  private_key_pem = "${tls_private_key.controller.0.private_key_pem}"

  subject {
    common_name  = "system:kube-controller-manager"
    organization = "Kubernetes"
  }
}

resource "tls_locally_signed_cert" "controller" {
  count              = "${var.k8s.pki.type == "local" ? 1 : 0}"
  ca_key_algorithm   = "ECDSA"
  ca_private_key_pem = "${tls_private_key.ca.0.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.0.cert_pem}"
  cert_request_pem   = "${tls_cert_request.controller.0.cert_request_pem}"

  validity_period_hours = 72
  early_renewal_hours   = 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}