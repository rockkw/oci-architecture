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
    source_type = "IMAGE"
    image_id    = local.node_image_id
  }

  node_config_details {
    size = var.node_pool_size

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = var.private_subnet_id
    }

    node_pool_pod_network_option_details {
      cni_type       = "OCI_VCN_IP_NATIVE"
      pod_subnet_ids = [var.private_subnet_id]
    }
  }

  ssh_public_key = var.ssh_public_key
}
