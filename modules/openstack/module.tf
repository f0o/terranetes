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

module "k8s" {
  source = "../kubernetes"
  k8s    = "${var.k8s}"
}

resource "openstack_networking_network_v2" "network" {
  name = "Terranetes"
}

resource "openstack_networking_subnet_v2" "subnet" {
  name            = "Terranetes"
  network_id      = "${openstack_networking_network_v2.network.id}"
  cidr            = "${local.k8s.network.cidr}"
  ip_version      = 4
  dns_nameservers = "${local.k8s.network.dns}"
  enable_dhcp     = "${local.k8s.network.dhcp}"
}

resource "openstack_networking_router_v2" "router" {
  count               = "${local.k8s.network.upstream == "" ? 0 : 1}"
  name                = "Terranetes"
  external_network_id = "${local.k8s.network.upstream}"
}

resource "openstack_networking_router_interface_v2" "router_interface" {
  count     = "${local.k8s.network.upstream == "" ? 0 : 1}"
  router_id = "${openstack_networking_router_v2.router[0].id}"
  subnet_id = "${openstack_networking_subnet_v2.subnet.id}"
}

resource "openstack_networking_port_v2" "port" {
  count      = "${length(local.k8s.nodes)}"
  name       = "Terranetes node #${count.index}"
  network_id = "${openstack_networking_network_v2.network.id}"
  fixed_ip {
    subnet_id  = "${openstack_networking_subnet_v2.subnet.id}"
    ip_address = "${local.k8s.nodes[count.index].ip}"
  }
}

resource "openstack_networking_secgroup_v2" "internal" {
  name = "Terranetes (internal)"
}

resource "openstack_networking_secgroup_rule_v2" "internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = "${openstack_networking_secgroup_v2.internal.id}"
  remote_group_id   = "${openstack_networking_secgroup_v2.internal.id}"
}

resource "openstack_compute_instance_v2" "node" {
  count               = "${length(local.k8s.nodes)}"
  name                = "k8s-${count.index}"
  image_name          = "${lookup(local.k8s.nodes[count.index], "image")}"
  flavor_name         = "${lookup(local.k8s.nodes[count.index], "type")}"
  user_data           = "${local.ignition[count.index]}"
  stop_before_destroy = true
  security_groups     = ["${openstack_networking_secgroup_v2.internal.id}"]
  network {
    port = "${openstack_networking_port_v2.port[count.index].id}"
  }
}

resource "openstack_networking_floatingip_v2" "fip" {
  count = "${local.k8s.network.fip ? length(local.k8s.nodes) : 0}"
  pool  = "185.243.23.80/28"
}

resource "openstack_compute_floatingip_associate_v2" "fip" {
  count       = "${local.k8s.network.fip ? length(local.k8s.nodes) : 0}"
  floating_ip = "${openstack_networking_floatingip_v2.fip[count.index].address}"
  instance_id = "${openstack_compute_instance_v2.node[count.index].id}"
  fixed_ip    = "${openstack_compute_instance_v2.node[count.index].network.0.fixed_ip_v4}"
}