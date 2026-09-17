terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.12.0" # oci_zpr_configuration / oci_zpr_zpr_policy require >= 6.12.0
    }
  }
}

provider "oci" {
  region = var.region
}

# --- Networking: VCN, public subnet, IGW, route table ---
# Standalone (not built on lab-network-stack) so this lab has no apply-order
# dependency on any other stack — see terraform/LABS.md's "Candidate lab" entry.

resource "oci_core_vcn" "zpr_vcn" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "zpr-lab-vcn"
  dns_label      = "zprlabvcn"
}

resource "oci_core_internet_gateway" "zpr_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.zpr_vcn.id
  display_name   = "zpr-lab-igw"
  enabled        = true
}

resource "oci_core_route_table" "zpr_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.zpr_vcn.id
  display_name   = "zpr-lab-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.zpr_igw.id
  }
}

# Matches the MyLearn scenario's Security List exactly: stateful ingress TCP/22
# from 0.0.0.0/0, stateful egress all/all. This is deliberately the OVER-PERMISSIVE
# starting point the scenario asks you to fix — see the NSG rule below for the fix,
# and the ZPR policy for the layer that holds even if this list is later loosened
# again by mistake.
resource "oci_core_security_list" "zpr_public_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.zpr_vcn.id
  display_name   = "zpr-lab-public-sl"

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    tcp_options {
      min = 22
      max = 22
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }
}

resource "oci_core_subnet" "zpr_public_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.zpr_vcn.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "zpr-lab-public-subnet"
  dns_label                  = "zprpub"
  route_table_id             = oci_core_route_table.zpr_rt.id
  security_list_ids          = [oci_core_security_list.zpr_public_sl.id]
  prohibit_public_ip_on_vnic = false
}

# --- NSG fix: "Allow SSH access to VM-02 only from VM-01" ---
# This is the scenario's own stated network-layer remediation, applied BEFORE
# ZPR, so the lab demonstrates both layers rather than skipping straight to ZPR.
# The security list above still allows 0.0.0.0/0:22 at the subnet level; this NSG
# is the tighter, resource-level control layered on top of it for VM-02 specifically.

resource "oci_core_network_security_group" "vm02_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.zpr_vcn.id
  display_name   = "zpr-lab-vm02-nsg"
}

resource "oci_core_network_security_group_security_rule" "vm02_allow_ssh_from_vm01" {
  network_security_group_id = oci_core_network_security_group.vm02_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = oci_core_instance.vm_01.private_ip
  source_type               = "CIDR_BLOCK"
  stateless                 = false
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# --- Compute: VM-01 (the only permitted SSH source) and VM-02 (the target) ---

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# --- ZPR: tenancy onboarding, namespace/attribute definitions, then policy ---
# NOTE: oci_zpr_configuration onboards ZPR at the TENANCY (root compartment) level,
# not per-lab — it is a one-time, tenancy-wide switch. If ZPR has already been
# enabled by any other means (Console, another stack), Terraform will show this
# as already satisfied rather than erroring; do not `terraform destroy` this
# resource as part of a routine teardown of just this lab, since other tenancy
# workloads may depend on ZPR staying enabled. See terraform/LABS.md's teardown
# notes — this is the one resource in the whole lab suite that is NOT scoped to
# this lab's own blast radius.
resource "oci_zpr_configuration" "tenancy_onboarding" {
  compartment_id = var.tenancy_ocid
  zpr_status     = "ENABLED"
}

# Security attribute namespace + attribute definition — the ZPR equivalent of
# oci_identity_tag_namespace/oci_identity_tag for regular defined tags, but under
# the separate "Security Attribute" service (oci_security_attribute_*, not
# oci_identity_*). This must exist before any resource can be tagged with it.
resource "oci_security_attribute_security_attribute_namespace" "zpr_lab_ns" {
  compartment_id = var.tenancy_ocid
  name           = "ZprLabRole"
  description    = "ZPR lab: classifies compute instances by their SSH trust role."
}

resource "oci_security_attribute_security_attribute" "ssh_role" {
  security_attribute_namespace_id = oci_security_attribute_security_attribute_namespace.zpr_lab_ns.id
  name                            = "SshRole"
  description                     = "trusted-source (may initiate SSH) or ssh-target (accepts SSH only from trusted-source)."

  validator {
    validator_type = "ENUM"
    values         = ["trusted-source", "ssh-target"]
  }
}

resource "oci_core_instance" "vm_01" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "zpr-lab-vm-01"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }

  # Tagged directly on the instance (not create_vnic_details — the OCI API
  # rejects security_attributes supplied in both places on the same launch).
  security_attributes = {
    "${oci_security_attribute_security_attribute_namespace.zpr_lab_ns.name}.${oci_security_attribute_security_attribute.ssh_role.name}.value" = "trusted-source"
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.zpr_public_subnet.id
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

resource "oci_core_instance" "vm_02" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "zpr-lab-vm-02"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }

  security_attributes = {
    "${oci_security_attribute_security_attribute_namespace.zpr_lab_ns.name}.${oci_security_attribute_security_attribute.ssh_role.name}.value" = "ssh-target"
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.zpr_public_subnet.id
    assign_public_ip = true
    nsg_ids          = [oci_core_network_security_group.vm02_nsg.id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

# The ZPR policy: mirrors the MyLearn CarCo/Science-App syntax exactly
# ("in <scope> allow <from> endpoints to connect to <to> endpoints"), but
# expressed against this lab's own namespace/attribute instead of a
# pre-existing one, since a real tenancy must define its own.
resource "oci_zpr_zpr_policy" "ssh_lockdown" {
  compartment_id = var.compartment_ocid
  name           = "zpr-lab-ssh-policy"
  description    = "Allow SSH from trusted-source to ssh-target only, independent of NSG/security-list state."

  statements = [
    "endpoint type='compute' from security_attribute='${oci_security_attribute_security_attribute_namespace.zpr_lab_ns.name}.${oci_security_attribute_security_attribute.ssh_role.name}.trusted-source' to security_attribute='${oci_security_attribute_security_attribute_namespace.zpr_lab_ns.name}.${oci_security_attribute_security_attribute.ssh_role.name}.ssh-target' with protocol='tcp/22' allow"
  ]

  depends_on = [oci_zpr_configuration.tenancy_onboarding]
}
