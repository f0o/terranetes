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
  ingress_types = {
    nginx = {
      urls = [
        "https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml",
        "https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/baremetal/service-nodeport.yaml"
      ]
    }
    nginx-terranetes = {
      urls = [
        "https://raw.githubusercontent.com/f0o/terranetes/master/modules/ingress/nginx.yaml",
      ]
    }
  }
  inject = {
    installer = ""
    alias     = {}
    hosts     = ""
    kubelet = {
      service = ""
      rkt     = ""
    }
  }
}