terraform {
  required_version = ">= 1.5.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}

provider "oci" {
  region = var.region
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_containerengine_node_pool_option" "oke_gpu_node_options" {
  node_pool_option_id = var.cluster_id
  compartment_id      = var.compartment_ocid
}

locals {
  node_image_id = [
    for source in data.oci_containerengine_node_pool_option.oke_gpu_node_options.sources :
    source.image_id if strcontains(source.source_name, "GPU") && strcontains(source.source_name, "Oracle-Linux")
  ][0]
}

resource "oci_containerengine_node_pool" "gpu_node_pool" {
  cluster_id         = var.cluster_id
  compartment_id     = var.compartment_ocid
  name               = "lab-gpu-node-pool"
  kubernetes_version = var.kubernetes_version
  node_shape         = var.node_shape

  node_source_details {
    source_type             = "IMAGE"
    image_id                = local.node_image_id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  # A larger boot volume isn't usable until the root partition is grown.
  # Oracle's documented pattern: fetch the OKE init script, run oci-growfs,
  # then run the init script. Needed because the vLLM image alone is ~20 GB
  # unpacked, which doesn't fit comfortably on the default 50 GB boot volume.
  node_metadata = {
    user_data = base64encode(<<-EOT
      #!/bin/bash
      curl --fail -H "Authorization: Bearer Oracle" -L0 http://169.254.169.254/opc/v2/instance/metadata/oke_init_script | base64 --decode >/var/run/oke-init.sh
      bash /usr/libexec/oci-growfs -y
      bash /var/run/oke-init.sh
    EOT
    )
  }

  node_config_details {
    size = var.node_pool_size
    # Without lab-oke-stack's workers NSG, GPU nodes hit the same
    # "register timeout" the CPU pool did (ports 6443/10250/12250 closed).
    nsg_ids = [var.workers_nsg_id]

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = var.private_subnet_id
    }

    node_pool_pod_network_option_details {
      cni_type       = "OCI_VCN_IP_NATIVE"
      pod_subnet_ids = [var.private_subnet_id]
      pod_nsg_ids    = [var.workers_nsg_id]
    }
  }

  ssh_public_key = var.ssh_public_key
}
