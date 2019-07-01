# terranetes
Kubernetes installer written in Terraform

## Kubernetes Object

```
variable "k8s" {
  default = {
    version = "1.14.3"                      # What Kubernetes release to use, PoC tested `on 1.14.3`
    image   = ""                            # What kubernetes image to use (defaults to `gcr.io/google-containers/hyperkube`)
    pubkeys = ["YOUR_PUBLIC_KEY"]           # List of SSH Public Keys to populate CoreOS with
    cni = {
      type    = "canal"                     # Can be either `canal`, `calico` or `weavenet` (Weavenet is currently not loading due to an ignition bug on redirects)
      version = "latest"                    # Version, `latest` is a safe value here
      extra   = false                       # Optionally install extra functionality (Weavenet-scope for example)
    }
    storages = [                            # List of Storage Providers, Only GlusterFS and EBS supported for the PoC
      {
        name = "ebs-io1"                    # Name of the Storage Class
        type = "ebs"                        # Type of the Storage Class (`glusterfs` or `ebs`)
        params = {                          # Paramters for the Storage Class, content varies
          fsType    = "ext4"
          type      = "io1"
          iopsPerGB = "10"
        }
      }
    ]
    etcd = {
      type      = "pod"                     # `pod` is the only supported type right now, later there will be also `vm`
      discovery = "static"                  # Either `static` or an URL from discovery.etcd.io
      image     = ""                        # Unused in the PoC, for later use when type==vm
      nodes = [{                            # Unused in the PoC, for later use when type==vm
        type  = ""
        image = ""
      }]
    }
    nodes = [                               # Arbitrary sized list of Nodes/VMs to generate configs for (later, to actually create the VMs)
      {
        type   = "4x4x10:X"                 # The Flavor/Instance-Type to create VMs from (not used yet)
        image  = "CoreOS 1632.3.0"          # The name of the Image / AMI / ... to boot (not used yet)
        labels = ["master"]                 # Arbitrary list of node-roles, needs at least one master node
      },
      {
        type   = "4x4x10:X"                 # The Flavor/Instance-Type to create VMs from (not used yet)
        image  = "CoreOS 1632.3.0"          # The name of the Image / AMI / ... to boot (not used yet)
        labels = ["compute"]                # Arbitrary list of node-roles, needs at least one master node
      },
    ]
    pki = {
      type = "local"                        # Only supported PKI for the PKI
    }
    network = {
      cidr     = "192.168.192.0/24"         # Hardcoded for the PoC due to lack of time
      base     = "50"                       # Hardcoded for the PoC due to lack of time
      dhcp     = ""                         # Unused for the PoC due to lack of time
      dns      = ""                         # Unused for the PoC due to lack of time
      upstream = ""                         # Unused for the PoC due to lack of time
    }
  }
}
```

## Example Terraform

This can be used with above object to create a 2 node cluster

```
module "k8s" {
  source = "./modules/kubernetes"
  k8s    = "${var.k8s}"
}

resource "openstack_compute_instance_v2" "node" {
  count               = "${length(module.k8s.k8s.nodes)}"
  name                = "k8s-${count.index}"
  image_name          = "${lookup(var.k8s.nodes[count.index], "image")}"
  flavor_name         = "${lookup(var.k8s.nodes[count.index], "type")}"
  user_data           = "${module.k8s.ignition[count.index]}"
  stop_before_destroy = true
  security_groups     = ["default", "sshd"]
  network {
    uuid        = "_SOME_NETWORK_UUID_"
    fixed_ip_v4 = "${module.k8s.k8s.nodes[count.index].ip}"
  }
}

resource "openstack_networking_floatingip_v2" "fip" {
  count = "${length(module.k8s.k8s.nodes)}"
  pool  = "_SOME_FLOATING_IP_POOL_"
}

resource "openstack_compute_floatingip_associate_v2" "fip" {
  count       = "${length(module.k8s.k8s.nodes)}"
  floating_ip = "${openstack_networking_floatingip_v2.fip[count.index].address}"
  instance_id = "${openstack_compute_instance_v2.node[count.index].id}"
  fixed_ip    = "${openstack_compute_instance_v2.node[count.index].network.0.fixed_ip_v4}"
}

output "fip" {
  value = "${openstack_networking_floatingip_v2.fip.*.address}"
}

output "admin" {
  value = "${module.k8s.pki.users.admin}"
}
```