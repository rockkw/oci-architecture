terraform {
  required_version = ">= 1.3.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 8.19.0"
    }
    cloudinit = { source = "hashicorp/cloudinit", version = ">= 2.2.0" }
    helm      = { source = "hashicorp/helm", version = ">= 3.0.1" }
    null      = { source = "hashicorp/null", version = ">= 3.2.1" }
    random    = { source = "hashicorp/random", version = ">= 3.4.3" }
    time      = { source = "hashicorp/time", version = ">= 0.9.1" }
  }
}

provider "oci" {
  region = var.region
}

# Required by the module (configuration_aliases = [oci.home] in its versions.tf)
# for identity/IAM operations — same home-region requirement lab-storage-stack
# hit directly (IAM writes are rejected outside the home region).
provider "oci" {
  alias  = "home"
  region = var.home_region
}

# Comparison stack for lab-oke-stack: this uses Oracle's own official Terraform
# module instead of hand-rolled resources, specifically to test whether its
# auto-provisioned network (7 purpose-built subnets + NSGs with the correct
# control-plane<->worker rules, per modules/network/nsg-controlplane.tf and
# nsg-workers.tf) avoids the node registration timeout lab-oke-stack hit with
# a hand-rolled 2-subnet, no-NSG network. See terraform/LABS.md for the full
# investigation and root-cause writeup.
module "oke" {
  source = "github.com/oracle-terraform-modules/terraform-oci-oke"
  providers = {
    oci      = oci
    oci.home = oci.home
  }

  tenancy_id     = var.tenancy_ocid
  compartment_id = var.compartment_ocid
  region         = var.region
  home_region    = var.home_region
  ssh_public_key = var.ssh_public_key

  # Cluster
  create_cluster          = true
  cluster_name            = "lab-oke-official-cluster"
  cluster_type            = "basic"
  control_plane_is_public = true

  # Network — let the module create its own purpose-built VCN/subnets/NSGs
  # rather than reusing lab-network-stack/lab-private-network-stack, so this
  # is a clean, isolated comparison against lab-oke-stack.
  create_vcn = true

  # Workers — small, cheap pool matching lab-oke-stack's shape for a fair
  # comparison.
  worker_pool_mode = "node-pool"
  worker_pools = {
    np1 = {
      size   = 2
      shape  = "VM.Standard.A1.Flex"
      ocpus  = 1
      memory = 6
    }
  }

  # No bastion/operator — keep this comparison focused on whether the
  # module's network/NSG setup alone resolves node registration, without
  # adding extra resources lab-oke-stack doesn't have either.
  create_bastion  = false
  create_operator = false
}
