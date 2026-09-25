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

# CPU-only node pool for the capstone's Phase 4 model (llama.cpp, see
# lab-capstone-vllm-stack). lab-oke-stack's 1 OCPU / 6 GB workers have about
# 0.84 CPU and 4.3 GB allocatable each, too little for a model server, so this
# stack adds one bigger A1 node to the same cluster. It's a separate stack for
# the same reason lab-oke-gpu-stack was: it bills, so it can be applied and
# destroyed on its own without touching the base cluster.

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Query the cluster itself (not "all") so only images valid for it come back.
data "oci_containerengine_node_pool_option" "oke_node_options" {
  node_pool_option_id = var.cluster_id
  compartment_id      = var.compartment_ocid
}

locals {
  # e.g. "Oracle-Linux-9.8-aarch64-2026.08.14-0-OKE-1.36.1-1699". Sources are
  # newest first. Matching the OKE version keeps the node image in step with
  # the cluster; excluding "GPU" keeps out the GPU builds.
  node_image_id = [
    for source in data.oci_containerengine_node_pool_option.oke_node_options.sources :
    source.image_id
    if strcontains(source.source_name, "Oracle-Linux")
    && strcontains(source.source_name, "aarch64")
    && strcontains(source.source_name, "OKE-${trimprefix(var.kubernetes_version, "v")}")
    && !strcontains(source.source_name, "GPU")
  ][0]
}

resource "oci_containerengine_node_pool" "cpu_inference_pool" {
  cluster_id         = var.cluster_id
  compartment_id     = var.compartment_ocid
  name               = "lab-cpu-inference-pool"
  kubernetes_version = var.kubernetes_version
  node_shape         = "VM.Standard.A1.Flex"

  node_shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  node_source_details {
    source_type = "IMAGE"
    image_id    = local.node_image_id
  }

  # The model Deployment selects on this label (nodeSelector workload=llm).
  initial_node_labels {
    key   = "workload"
    value = "llm"
  }

  node_config_details {
    size = var.node_pool_size
    # Same NSG as the CPU workers, so the node can register with the control
    # plane (6443/10250/12250) and lab-capstone-vllm-stack's LB rules apply.
    nsg_ids = [var.workers_nsg_id]

    # AD-1: same AD as the other pools, and the model cache PVC (an AD-bound
    # block volume) is created where this node is.
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
