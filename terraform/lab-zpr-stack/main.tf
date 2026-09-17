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

# ZPR configuration (tenancy onboarding) is a CREATE/UPDATE/DELETE-in-home-region-only
# operation per the OCI API — confirmed by a real 405 MethodNotAllowed on first apply
# when this stack's default region (us-phoenix-1) wasn't the tenancy's home region
# (us-ashburn-1/IAD). Same home-region-write pattern already documented in Note 5's
# IAM section, now hit for a second, unrelated service.
provider "oci" {
  alias  = "home_region"
  region = var.home_region
}

# --- Networking: VCN, public subnet, IGW, route table ---
# Standalone (not built on lab-network-stack) so this lab has no apply-order
# dependency on any other stack — see terraform/LABS.md's "Candidate lab" entry.

resource "oci_core_vcn" "zpr_vcn" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "zpr-lab-vcn"
  dns_label      = "zprlabvcn"

  # NOTE: VCN-level security_attributes are DISABLED here, not just unset.
  # Every attempt to set them (create AND update, home-region and default
  # provider, enforce AND audit mode) returned a real, reproducible
  # 400 "Invalid tags" from UpdateVcn — a genuine unresolved API/provider
  # issue, not a config mistake caught so far. This means the ZPR policy's
  # "in ZprLabRole.Network:zpr-lab-vcn VCN" location clause currently has
  # NOTHING to match, since the VCN was never successfully tagged. See
  # Lab 5's "Known unresolved question" section for the live investigation.
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
  # CIDR_BLOCK requires an actual CIDR, not a bare IP — confirmed by a real
  # 400 ("CIDR 10.0.1.75 is invalid: unable to parse") on first apply against
  # oci_core_instance.vm_01.private_ip alone; /32 makes it a valid single-host CIDR.
  source      = "${oci_core_instance.vm_01.private_ip}/32"
  source_type = "CIDR_BLOCK"
  stateless   = false
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
  provider       = oci.home_region
  compartment_id = var.tenancy_ocid
  zpr_status     = "ENABLED"
}

# Security attribute namespace + attribute definition — the ZPR equivalent of
# oci_identity_tag_namespace/oci_identity_tag for regular defined tags, but under
# the separate "Security Attribute" service (oci_security_attribute_*, not
# oci_identity_*). This must exist before any resource can be tagged with it.
# Also applied via the home-region provider: tenancy-scoped identity/tag-like
# resources in OCI are consistently home-region-write-only (same rule as IAM
# users/groups/policies and now ZPR onboarding above).
resource "oci_security_attribute_security_attribute_namespace" "zpr_lab_ns" {
  provider       = oci.home_region
  compartment_id = var.tenancy_ocid
  name           = "ZprLabRole"
  description    = "ZPR lab: classifies compute instances by their SSH trust role."
}

resource "oci_security_attribute_security_attribute" "ssh_role" {
  provider                        = oci.home_region
  security_attribute_namespace_id = oci_security_attribute_security_attribute_namespace.zpr_lab_ns.id
  name                            = "SshRole"
  description                     = "trusted-source (may initiate SSH) or ssh-target (accepts SSH only from trusted-source)."

  validator {
    validator_type = "ENUM"
    values         = ["trusted-source", "ssh-target"]
  }
}

# A SEPARATE attribute for the "in <location> VCN" clause — ZPR Policy
# Language's location scope and its endpoint-matching attributes are
# different security attributes, confirmed against Oracle's real policy
# examples (e.g. "in networks:net1 VCN allow compute:instance1 endpoints...")
# where "networks:net1" (the VCN's own tag) is distinct from "compute:instance1"
# (the endpoint's tag). SshRole alone conflated these on the first attempt.
resource "oci_security_attribute_security_attribute" "vcn_scope" {
  provider                        = oci.home_region
  security_attribute_namespace_id = oci_security_attribute_security_attribute_namespace.zpr_lab_ns.id
  name                            = "Network"
  description                     = "Tags the lab VCN so ZPR policy statements can scope to it via the 'in <attr> VCN' clause."

  validator {
    validator_type = "ENUM"
    values         = ["zpr-lab-vcn"]
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
  # Both .value AND .mode are required per resource — confirmed by a real
  # 400 ("missing a required key Optional[mode]") on first apply; "enforce"
  # means ZPR actually blocks non-matching traffic (vs. "audit", which only
  # logs would-be violations without blocking).
  security_attributes = {
    "${oci_security_attribute_security_attribute_namespace.zpr_lab_ns.name}.${oci_security_attribute_security_attribute.ssh_role.name}.value" = "trusted-source"
    "${oci_security_attribute_security_attribute_namespace.zpr_lab_ns.name}.${oci_security_attribute_security_attribute.ssh_role.name}.mode"  = "enforce"
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
    "${oci_security_attribute_security_attribute_namespace.zpr_lab_ns.name}.${oci_security_attribute_security_attribute.ssh_role.name}.mode"  = "enforce"
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
  provider = oci.home_region
  # Tenancy root, not var.compartment_ocid (sandbox) — a real 400 "Invalid
  # compartmentId" against sandbox, even with the home-region provider fix
  # already applied, points at the ZPR policy resource itself being
  # tenancy-root-scoped like oci_zpr_configuration and the security-attribute
  # namespace above, not arbitrary-compartment-scoped like a regular policy.
  compartment_id = var.tenancy_ocid
  name           = "zpr-lab-ssh-policy"
  description    = "Allow SSH from trusted-source to ssh-target only, independent of NSG/security-list state."

  # Real ZPR Policy Language grammar (verified against Oracle's official
  # Policy Syntax/Examples docs, confirmed by a real 400 "policy contains
  # invalid statements" on the first, invented "endpoint type=... from ...
  # to ... allow" attempt):
  #   in <namespace.key:value> VCN allow <namespace.key:value> endpoints
  #   to connect to <namespace.key:value> endpoints with protocol='tcp/PORT'
  # Attribute references use "namespace.key:value" (dot then COLON) —
  # not "namespace.key.value" (all dots), which was this stack's second bug.
  statements = [
    "in ${oci_security_attribute_security_attribute_namespace.zpr_lab_ns.name}.${oci_security_attribute_security_attribute.vcn_scope.name}:zpr-lab-vcn VCN allow ${oci_security_attribute_security_attribute_namespace.zpr_lab_ns.name}.${oci_security_attribute_security_attribute.ssh_role.name}:trusted-source endpoints to connect to ${oci_security_attribute_security_attribute_namespace.zpr_lab_ns.name}.${oci_security_attribute_security_attribute.ssh_role.name}:ssh-target endpoints with protocol='tcp/22'"
  ]

  depends_on = [oci_zpr_configuration.tenancy_onboarding]
}
