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
    etcd = object({
      type      = string
      discovery = string
      image     = string
      instance = object({
        type = string
      })
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
    }))
  })
}

locals {
  k8s = {
    version       = "v${var.k8s.version}"
    version_short = "v${join("", slice(split(".", var.k8s.version), 0, 1))}"
    image         = "${var.k8s.image != "" ? var.k8s.image : "docker://gcr.io/google-containers/hyperkube"}"
    cni           = "${var.k8s.cni}"
    storages      = "${var.k8s.storages}"
    pubkeys       = "${var.k8s.pubkeys}"
    etcd          = "${var.k8s.etcd}"
  }
}