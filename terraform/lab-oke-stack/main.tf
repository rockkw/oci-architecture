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

data "oci_containerengine_cluster_option" "oke_options" {
  cluster_option_id = "all"
  compartment_id    = var.compartment_ocid
}

data "oci_containerengine_node_pool_option" "oke_node_options" {
  node_pool_option_id = "all"
  compartment_id      = var.compartment_ocid
  node_pool_os_arch   = "AARCH64"
}

locals {
  kubernetes_version = coalesce(
    var.kubernetes_version,
    data.oci_containerengine_cluster_option.oke_options.kubernetes_versions[
      length(data.oci_containerengine_cluster_option.oke_options.kubernetes_versions) - 1
    ]
  )

  node_image_id = [
    for source in data.oci_containerengine_node_pool_option.oke_node_options.sources :
    source.image_id if strcontains(source.source_name, "Oracle-Linux") && strcontains(source.source_name, "aarch64")
  ][0]
}

resource "oci_containerengine_cluster" "lab_cluster" {
  compartment_id     = var.compartment_ocid
  name               = "lab-oke-cluster"
  kubernetes_version = local.kubernetes_version
  vcn_id             = var.vcn_id
  type               = "BASIC_CLUSTER"

  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = var.public_subnet_id
  }

  cluster_pod_network_options {
    cni_type = "OCI_VCN_IP_NATIVE"
  }

  options {
    service_lb_subnet_ids = [var.public_subnet_id]
  }
}

resource "oci_containerengine_node_pool" "lab_node_pool" {
  cluster_id         = oci_containerengine_cluster.lab_cluster.id
  compartment_id     = var.compartment_ocid
  name               = "lab-node-pool"
  kubernetes_version = local.kubernetes_version
  node_shape         = "VM.Standard.A1.Flex"

  node_shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

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
