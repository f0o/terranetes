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
        type = "aws"                        # Type of the Storage Class (`glusterfs` or `ebs`)
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
      image     = ""                        # Image to use, defaults to `k8s.gcr.io/etcd:3.3.10`
      nodes = [{                            # Unused in the PoC, for later use when type==vm
        type  = ""
        image = ""
      }]
    }
    nodes = [                               # Arbitrary sized list of Nodes/VMs to generate configs for (later, to actually create the VMs)
      {
        type    = "4x4x10:X"                # The Flavor/Instance-Type to create VMs from (not used yet)
        image   = "CoreOS 1632.3.0"         # The name of the Image / AMI / ... to boot (not used yet)
        labels  = ["master"]                # Arbitrary list of node-roles, needs at least one master node
        version = ""                        # Version override - empty means take version from upper level
      },
      {
        type    = "4x4x10:X"                # The Flavor/Instance-Type to create VMs from (not used yet)
        image   = "CoreOS 1632.3.0"         # The name of the Image / AMI / ... to boot (not used yet)
        labels  = ["compute"]               # Arbitrary list of node-roles, needs at least one master node
        version = ""                        # Version override - empty means take version from upper level
      },
    ]
    pki = {
      type = "local"                        # Only supported PKI for the PKI
    }
    network = {
      cidr     = "192.168.123.0/24"         # CIDR for private network
      base     = "50"                       # Base IP for allocation of nodes
      dhcp     = true                       # Toggle for DHCP settings on network
      dns      = ["8.8.8.8"]                # List of DNS Servers
      upstream = "abcd123"                  # Network UUID/Parameter used for providers (UUID of external network for OpenStack)
      fip      = true                       # Toggle to create Floating IPs (or equivalent) and attach them to the Masters or the Loadbalancer
      pool     = "FloatingPool"             # Pool to assign Floating IPs from
    }
    loadbalancer = {
      enable = true                         # Boolean to enable or disable Loadbalancer deployment
      type   = "lbaas"                      # Currently only 'lbaas' supported, later 'vm' and 'external' is also supported
    }
    ingress = {
      enable = true                         # Boolean to enable or disable ingress (might change or be depending on ingress roles)
      type   = "nginx-terranetes"           # Currently only 'nginx' and 'nginx-terranetes' supported, the latter is an adapted version of nginx ingress for role selction
      specs  = {}                           # Future use maybe
    }
  }
}
```

## Example Terraform

This can be used with above object to create a 2 node cluster based on the OpenStack Provider (LBaaSv2 required, flip `loadbalancer.enable` to `false` if unavailable)

```
module "openstack" {
  source = "./modules/openstack"
  k8s    = "${var.k8s}"
}

output "admin" {
  value = "${module.openstack.pki.users.admin}"
}
```
