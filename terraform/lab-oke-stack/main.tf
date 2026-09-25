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

# NSGs for control-plane <-> worker-node traffic. lab-oke-stack originally had
# no NSG at all and relied on the default security list (SSH/ICMP/443 only),
# which caused node registration to time out — workers could never reach the
# control plane's Kubelet/API endpoints. Rules below mirror the minimum set
# from Oracle's official terraform-oci-oke module (modules/network/nsg-
# controlplane.tf and nsg-workers.tf), trimmed to just what this stack needs
# (no bastion/pod/FSS/LB-specific rules, since this stack doesn't use those).
resource "oci_core_network_security_group" "control_plane" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "lab-oke-control-plane-nsg"
}

resource "oci_core_network_security_group" "workers" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "lab-oke-workers-nsg"
}

locals {
  apiserver_port    = 6443
  kubelet_api_port  = 10250
  oke_port          = 12250
  health_check_port = 10256
}

# Control plane -> workers
resource "oci_core_network_security_group_security_rule" "cp_egress_to_workers_kubelet" {
  network_security_group_id = oci_core_network_security_group.control_plane.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = oci_core_network_security_group.workers.id
  destination_type          = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = local.kubelet_api_port
      max = local.kubelet_api_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "cp_ingress_from_workers" {
  network_security_group_id = oci_core_network_security_group.control_plane.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.workers.id
  source_type               = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = local.apiserver_port
      max = local.apiserver_port
    }
  }
}

# External kubectl clients (e.g. a laptop) also need to reach the API
# endpoint — the worker rule above only covers node<->control-plane traffic.
# The public subnet's security list already allows 443 from anywhere; this
# mirrors that for 6443.
resource "oci_core_network_security_group_security_rule" "cp_ingress_from_internet" {
  network_security_group_id = oci_core_network_security_group.control_plane.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = local.apiserver_port
      max = local.apiserver_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "cp_egress_to_workers_oke_port" {
  network_security_group_id = oci_core_network_security_group.control_plane.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = oci_core_network_security_group.workers.id
  destination_type          = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = local.oke_port
      max = local.oke_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "cp_ingress_from_workers_oke_port" {
  network_security_group_id = oci_core_network_security_group.control_plane.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.workers.id
  source_type               = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = local.oke_port
      max = local.oke_port
    }
  }
}

# Workers -> control plane
resource "oci_core_network_security_group_security_rule" "workers_egress_to_cp_apiserver" {
  network_security_group_id = oci_core_network_security_group.workers.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = oci_core_network_security_group.control_plane.id
  destination_type          = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = local.apiserver_port
      max = local.apiserver_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "workers_egress_to_cp_oke_port" {
  network_security_group_id = oci_core_network_security_group.workers.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = oci_core_network_security_group.control_plane.id
  destination_type          = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = local.oke_port
      max = local.oke_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "workers_egress_to_cp_kubelet_health" {
  network_security_group_id = oci_core_network_security_group.workers.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = oci_core_network_security_group.control_plane.id
  destination_type          = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = local.kubelet_api_port
      max = local.kubelet_api_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "workers_ingress_from_cp" {
  network_security_group_id = oci_core_network_security_group.workers.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.control_plane.id
  source_type               = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = local.health_check_port
      max = local.health_check_port
    }
  }
}

# The API server calls the kubelet on 10250 for `kubectl logs`, `exec` and
# `port-forward`. workers_ingress_from_cp above only opens the 10256 health
# port, so those commands timed out with "dial tcp <node>:10250: i/o timeout".
resource "oci_core_network_security_group_security_rule" "workers_ingress_from_cp_kubelet" {
  network_security_group_id = oci_core_network_security_group.workers.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.control_plane.id
  source_type               = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = local.kubelet_api_port
      max = local.kubelet_api_port
    }
  }
}

# Workers <-> workers (pod-to-pod / node-to-node traffic)
resource "oci_core_network_security_group_security_rule" "workers_egress_to_workers" {
  network_security_group_id = oci_core_network_security_group.workers.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = oci_core_network_security_group.workers.id
  destination_type          = "NETWORK_SECURITY_GROUP"
}

resource "oci_core_network_security_group_security_rule" "workers_ingress_from_workers" {
  network_security_group_id = oci_core_network_security_group.workers.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = oci_core_network_security_group.workers.id
  source_type               = "NETWORK_SECURITY_GROUP"
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
    nsg_ids              = [oci_core_network_security_group.control_plane.id]
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
    size    = var.node_pool_size
    nsg_ids = [oci_core_network_security_group.workers.id]

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = var.private_subnet_id
    }

    node_pool_pod_network_option_details {
      cni_type       = "OCI_VCN_IP_NATIVE"
      pod_subnet_ids = [var.private_subnet_id]
      pod_nsg_ids    = [oci_core_network_security_group.workers.id]
    }
  }

  ssh_public_key = var.ssh_public_key
}
