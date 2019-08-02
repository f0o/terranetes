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

resource "openstack_networking_secgroup_rule_v2" "sshd" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.internal.id}"
}

resource "openstack_networking_secgroup_rule_v2" "k8s" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.internal.id}"
}

resource "openstack_networking_secgroup_rule_v2" "lbaas-kube-api" {
  count             = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" ? 1 : 0}"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "${local.k8s.network.cidr}"
  security_group_id = "${openstack_networking_secgroup_v2.internal.id}"
}

resource "openstack_networking_secgroup_rule_v2" "lbaas-etcd" {
  count             = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" ? 1 : 0}"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2379
  port_range_max    = 2379
  remote_ip_prefix  = "${local.k8s.network.cidr}"
  security_group_id = "${openstack_networking_secgroup_v2.internal.id}"
}

resource "openstack_networking_secgroup_v2" "ingress" {
  count = "${local.k8s.ingress.enable == true ? 1 : 0}"
  name  = "Terranetes (ingress)"
}

resource "openstack_networking_secgroup_rule_v2" "http" {
  count             = "${local.k8s.ingress.enable == true ? 1 : 0}"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.ingress.0.id}"
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  count             = "${local.k8s.ingress.enable == true ? 1 : 0}"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.ingress.0.id}"
}

resource "openstack_compute_instance_v2" "node" {
  count               = "${length(local.k8s.nodes)}"
  name                = "${lookup(local.k8s.nodes[count.index], "name")}"
  image_name          = "${lookup(local.k8s.nodes[count.index], "image")}"
  flavor_name         = "${lookup(local.k8s.nodes[count.index], "type")}"
  user_data           = "${local.ignition[count.index].rendered}"
  stop_before_destroy = true
  security_groups     = compact(["${openstack_networking_secgroup_v2.internal.name}", "${contains(local.k8s.nodes[count.index].labels, "ingress") ? "${openstack_networking_secgroup_v2.ingress.0.name}" : ""}"])
  network {
    port = "${openstack_networking_port_v2.port[count.index].id}"
  }
}

resource "openstack_networking_floatingip_v2" "fip" {
  count = "${local.k8s.network.fip ? local.k8s.loadbalancer.enable ? 1 : length(distinct([for k, v in local.k8s.nodes : k if contains(v.labels, "master") || (local.k8s.ingress.enable && contains(v.labels, "ingress"))])) : 0}"
  pool  = "${local.k8s.network.pool}"
}

resource "openstack_networking_floatingip_associate_v2" "fip" {
  count       = "${local.k8s.network.fip ? local.k8s.loadbalancer.enable ? 1 : length(distinct([for k, v in local.k8s.nodes : k if contains(v.labels, "master") || (local.k8s.ingress.enable && contains(v.labels, "ingress"))])) : 0}"
  floating_ip = "${openstack_networking_floatingip_v2.fip[count.index].address}"
  port_id     = "${local.k8s.loadbalancer.enable ? local.k8s.loadbalancer.type == "lbaas" ? openstack_lb_loadbalancer_v2.terranetes.0.vip_port_id : "" : openstack_networking_port_v2.port[element(distinct([for k, v in local.k8s.nodes : k if contains(v.labels, "master") || (local.k8s.ingress.enable && contains(v.labels, "ingress"))]), count.index)].id}"
}

resource "openstack_lb_loadbalancer_v2" "terranetes" {
  name          = "Terranetes"
  count         = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" ? 1 : 0}"
  vip_subnet_id = "${openstack_networking_subnet_v2.subnet.id}"
  vip_address   = "${local.k8s.network.lb}"
}

resource "openstack_lb_listener_v2" "kube-api" {
  name            = "kube-api"
  count           = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" ? 1 : 0}"
  loadbalancer_id = "${openstack_lb_loadbalancer_v2.terranetes.0.id}"
  protocol        = "TCP"
  protocol_port   = 6443
}

resource "openstack_lb_listener_v2" "etcd" {
  name            = "etcd"
  count           = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" ? 1 : 0}"
  loadbalancer_id = "${openstack_lb_loadbalancer_v2.terranetes.0.id}"
  protocol        = "TCP"
  protocol_port   = 2379
}

resource "openstack_lb_listener_v2" "http" {
  name            = "http"
  count           = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" && local.k8s.ingress.enable ? 1 : 0}"
  loadbalancer_id = "${openstack_lb_loadbalancer_v2.terranetes.0.id}"
  protocol        = "TCP"
  protocol_port   = 80
}

resource "openstack_lb_listener_v2" "https" {
  name            = "https"
  count           = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" && local.k8s.ingress.enable ? 1 : 0}"
  loadbalancer_id = "${openstack_lb_loadbalancer_v2.terranetes.0.id}"
  protocol        = "TCP"
  protocol_port   = 443
}

resource "openstack_lb_pool_v2" "kube-api" {
  name        = "kube-api"
  count       = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" ? 1 : 0}"
  listener_id = "${openstack_lb_listener_v2.kube-api.0.id}"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
}

resource "openstack_lb_pool_v2" "etcd" {
  name        = "etcd"
  count       = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" ? 1 : 0}"
  listener_id = "${openstack_lb_listener_v2.etcd.0.id}"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
}

resource "openstack_lb_pool_v2" "http" {
  name        = "http"
  count       = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" && local.k8s.ingress.enable ? 1 : 0}"
  listener_id = "${openstack_lb_listener_v2.http.0.id}"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
}

resource "openstack_lb_pool_v2" "https" {
  name        = "https"
  count       = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" && local.k8s.ingress.enable ? 1 : 0}"
  listener_id = "${openstack_lb_listener_v2.https.0.id}"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
}

resource "openstack_lb_monitor_v2" "kube-api" {
  name        = "kube-api"
  count       = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" ? 1 : 0}"
  pool_id     = "${openstack_lb_pool_v2.kube-api.0.id}"
  type        = "TCP"
  delay       = 5
  timeout     = 3
  max_retries = 3
}

resource "openstack_lb_monitor_v2" "etcd" {
  name        = "etcd"
  count       = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" ? 1 : 0}"
  pool_id     = "${openstack_lb_pool_v2.etcd.0.id}"
  type        = "TCP"
  delay       = 5
  timeout     = 3
  max_retries = 3
}

resource "openstack_lb_monitor_v2" "http" {
  name        = "http"
  count       = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" && local.k8s.ingress.enable ? 1 : 0}"
  pool_id     = "${openstack_lb_pool_v2.http.0.id}"
  type        = "TCP"
  delay       = 5
  timeout     = 3
  max_retries = 3
}

resource "openstack_lb_monitor_v2" "https" {
  name        = "https"
  count       = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" && local.k8s.ingress.enable ? 1 : 0}"
  pool_id     = "${openstack_lb_pool_v2.https.0.id}"
  type        = "TCP"
  delay       = 5
  timeout     = 3
  max_retries = 3
}

resource "openstack_lb_member_v2" "kube-api" {
  name          = "kube-api"
  count         = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" ? length(local.masters) : 0}"
  pool_id       = "${openstack_lb_pool_v2.kube-api.0.id}"
  subnet_id     = "${openstack_networking_subnet_v2.subnet.id}"
  address       = "${local.masters[count.index].ip}"
  protocol_port = 6443
}

resource "openstack_lb_member_v2" "etcd" {
  name          = "etcd"
  count         = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" && local.k8s.etcd.type == "pod" ? length(local.masters) : 0}"
  pool_id       = "${openstack_lb_pool_v2.etcd.0.id}"
  subnet_id     = "${openstack_networking_subnet_v2.subnet.id}"
  address       = "${local.masters[count.index].ip}"
  protocol_port = 2379
}

resource "openstack_lb_member_v2" "http" {
  name          = "http"
  count         = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" && local.k8s.ingress.enable ? length(local.ingresses) : 0}"
  pool_id       = "${openstack_lb_pool_v2.http.0.id}"
  subnet_id     = "${openstack_networking_subnet_v2.subnet.id}"
  address       = "${local.ingresses[count.index].ip}"
  protocol_port = 80
}

resource "openstack_lb_member_v2" "https" {
  name          = "https"
  count         = "${local.k8s.loadbalancer.enable && local.k8s.loadbalancer.type == "lbaas" && local.k8s.ingress.enable ? length(local.ingresses) : 0}"
  pool_id       = "${openstack_lb_pool_v2.https.0.id}"
  subnet_id     = "${openstack_networking_subnet_v2.subnet.id}"
  address       = "${local.ingresses[count.index].ip}"
  protocol_port = 443
}