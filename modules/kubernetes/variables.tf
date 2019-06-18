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
  default = {
    type    = "canal"
    version = "latest"
  }
}

variable "sc" {
  description = "List of StorageClass Objects"
  type = list(object({name = string, type = string, params = map(string)}))
  default = [
    {
      name = "ebs-io1"
      type = "ebs"
      params = {
        fsType    = "ext4"
        type      = "io1"
        iopsPerGB = "10"
      }
    },
    {
      name = "glusterfs"
      type = "glusterfs"
      params = {
        resturl = "localhost"
        clusterid = "123"
        restkey = "password"
      }
    },
  ]
}
