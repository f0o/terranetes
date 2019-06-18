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

variable "cni" {
  description = "CNI Object containing `type` and `version`"
  type        = object({ type = string, version = string })
}

variable "cni_types" {
  default = {
    canal = {
      version = "3.7"
      url     = "https://docs.projectcalico.org/v%s/manifests/canal.yaml"
    }
    calico = {
      version = "3.7"
      url     = "https://docs.projectcalico.org/v%s/manifests/calico.yaml"
    }
    calico-typha = {
      version = "3.7"
      url     = "https://docs.projectcalico.org/v%s/manifests/calico-typha.yaml"
    }
  }
}
