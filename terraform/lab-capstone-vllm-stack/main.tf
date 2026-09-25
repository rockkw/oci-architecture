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

# This stack owns only the OCI-side network pieces for the Phase 4 model endpoint.
# The Kubernetes objects (Namespace, PVC, Deployment, Service) are rendered from
# llama-server.yaml.tftpl into the `vllm_manifest` output and applied by hand with
# kubectl, the same split lab-oke-app-stack uses (no kubernetes/helm provider in
# this repo).
#
# CPU-only: the model is served by llama.cpp's llama-server on
# lab-oke-cpu-inference-pool-stack's A1 node. The stack, output and Kubernetes
# names still say "vllm" from the original GPU design; renaming them would
# replace the NSG and change the Function's config for no gain.
#
# Traffic path: client in 10.0.2.0/24 -> internal LB (TCP 80, in 10.0.2.0/24)
# -> worker node NodePort (30000-32767) -> llama-server pod (8000).
# The Service sets security-rule-management-mode = "None", so the cloud controller
# manager doesn't touch security lists or create NSGs. Every rule it would have
# added is declared here instead, where Terraform can see and destroy it.

locals {
  node_port_min     = 30000
  node_port_max     = 32767
  health_check_port = 10256 # kube-proxy /healthz, used by the LB for externalTrafficPolicy=Cluster
}

resource "oci_core_network_security_group" "vllm_lb" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "lab-capstone-vllm-lb-nsg"
}

# Clients -> LB. Only the private subnet (MyMagnet instances, the Phase 3
# Function, and the Phase 2 ADB private endpoint) can reach the listener.
resource "oci_core_network_security_group_security_rule" "lb_ingress_from_clients" {
  network_security_group_id = oci_core_network_security_group.vllm_lb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.client_cidr
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = var.listener_port
      max = var.listener_port
    }
  }
}

# LB -> worker NodePorts
resource "oci_core_network_security_group_security_rule" "lb_egress_to_workers_nodeport" {
  network_security_group_id = oci_core_network_security_group.vllm_lb.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = var.workers_nsg_id
  destination_type          = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = local.node_port_min
      max = local.node_port_max
    }
  }
}

# LB -> kube-proxy health check
resource "oci_core_network_security_group_security_rule" "lb_egress_to_workers_health" {
  network_security_group_id = oci_core_network_security_group.vllm_lb.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = var.workers_nsg_id
  destination_type          = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = local.health_check_port
      max = local.health_check_port
    }
  }
}

# Rules added to lab-oke-stack's workers NSG. They reference that NSG by OCID
# rather than owning it, so destroying this stack removes only these two rules.
# The inference node pool must be in the workers NSG for these to apply (see
# lab-oke-cpu-inference-pool-stack's workers_nsg_id variable).
resource "oci_core_network_security_group_security_rule" "workers_ingress_from_lb_nodeport" {
  network_security_group_id = var.workers_nsg_id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.vllm_lb.id
  source_type               = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = local.node_port_min
      max = local.node_port_max
    }
  }
}

resource "oci_core_network_security_group_security_rule" "workers_ingress_from_lb_health" {
  network_security_group_id = var.workers_nsg_id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.vllm_lb.id
  source_type               = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = local.health_check_port
      max = local.health_check_port
    }
  }
}

locals {
  model_url = "https://huggingface.co/${var.model_repo}/resolve/${var.model_revision}/${var.model_file}"

  vllm_manifest = templatefile("${path.module}/llama-server.yaml.tftpl", {
    namespace           = var.namespace
    lb_subnet_id        = var.private_subnet_id
    lb_nsg_id           = oci_core_network_security_group.vllm_lb.id
    listener_port       = var.listener_port
    node_workload_label = var.node_workload_label
    image               = var.llama_server_image
    model_file          = var.model_file
    model_url           = local.model_url
    model_sha256        = var.model_sha256
    served_model_name   = var.served_model_name
    max_model_len       = var.max_model_len
    threads             = var.threads
    cpu_request         = var.cpu_request
    memory_request      = var.memory_request
    memory_limit        = var.memory_limit
    model_cache_size_gb = var.model_cache_size_gb
  })
}
