terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.12.0" # matches lab-zpr-stack's floor -- oci_zpr_* resources need it
    }
  }
}

provider "oci" {
  region = var.region
}

# ZPR tenancy onboarding, the security attribute namespace/attribute, and the
# ZPR policy itself are all home-region-write-only -- same rule already
# confirmed for IAM and for lab-zpr-stack's own ZPR resources. See that
# stack's main.tf for the full "why" (a real 405 MethodNotAllowed was hit
# there first).
provider "oci" {
  alias  = "home_region"
  region = var.home_region
}

# --- Networking: reuses lab-network-stack's VCN and lab-private-network-stack's
# private subnet (NAT + Service Gateway already provisioned there) rather than
# building new networking -- the DB system gets no public IP and reaches
# Object Storage (patching/backups) via the Service Gateway, not the internet,
# per this lab's own scoping decision. See terraform/LABS.md.

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# --- NSG: DB listener port only, from the operator's own CIDR -- nothing
# public. Mirrors lab-bastion-stack's "no public IP, SSH only from a known
# source" pattern, but for the DB listener port instead of SSH.
resource "oci_core_network_security_group" "basedb_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "basedb-lab-nsg"
}

resource "oci_core_network_security_group_security_rule" "allow_db_listener" {
  network_security_group_id = oci_core_network_security_group.basedb_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.db_client_allowed_cidr
  source_type               = "CIDR_BLOCK"
  stateless                 = false
  tcp_options {
    destination_port_range {
      min = var.db_listener_port
      max = var.db_listener_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "egress_all" {
  network_security_group_id = oci_core_network_security_group.basedb_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  stateless                 = false
}

# --- ZPR: tenancy onboarding + namespace/attribute + policy ---
# Same pattern as lab-zpr-stack, applied to a database endpoint instead of a
# compute instance -- confirms ZPR isn't compute-only (see the MyLearn Note 6
# capture: "ZPR security attributes identify the resources you want to
# protect, such as compute instances and databases").
#
# NOT re-onboarding ZPR at the tenancy level here -- oci_zpr_configuration is
# a ONE-TIME, tenancy-wide switch (see lab-zpr-stack's own comment on this).
#
# REAL BUG FOUND AND FIXED (first apply attempt): originally declared as a
# `resource "oci_zpr_configuration"`, matching lab-zpr-stack's own pattern.
# That's wrong when lab-zpr-stack has ALREADY applied in this tenancy: the
# live API returned a real 409 Conflict ("Failed to create ZPR
# Configuration. Configuration already exists in <tenancy> compartment")
# because this is a tenancy-wide SINGLETON -- only one Terraform state can
# `resource`-own it. Importing it into this stack's state too was
# considered and rejected: a future `terraform destroy` on THIS stack would
# then try to delete tenancy-wide ZPR onboarding that lab-zpr-stack still
# depends on, silently breaking that stack. Switched to a `data` source
# instead -- a read-only confirmation that ZPR is enabled, with no create/
# destroy lifecycle of its own, which is what "no-op confirmation, not a
# fresh onboarding" (see below) actually requires.
data "oci_zpr_configuration" "tenancy_onboarding" {
  provider       = oci.home_region
  compartment_id = var.tenancy_ocid
}

# A SEPARATE namespace from lab-zpr-stack's ZprLabRole -- this lab's own
# resources, not reusing another lab's namespace, so it stays independently
# destroyable without touching lab-zpr-stack's tags.
resource "oci_security_attribute_security_attribute_namespace" "basedb_ns" {
  provider       = oci.home_region
  compartment_id = var.tenancy_ocid
  name           = "BaseDbLabRole"
  description    = "BaseDB lab: classifies which endpoints may reach the database listener."
}

resource "oci_security_attribute_security_attribute" "db_role" {
  provider                        = oci.home_region
  security_attribute_namespace_id = oci_security_attribute_security_attribute_namespace.basedb_ns.id
  name                             = "DbRole"
  description                      = "sensitive (the protected database) or db-client (permitted to connect to it)."

  validator {
    validator_type = "ENUM"
    values         = ["sensitive", "db-client"]
  }
}

# The VCN-scope attribute ZPR's "in <location> VCN" clause needs -- same
# separate-attribute-for-location pattern lab-zpr-stack's own comments flag
# as a real, confirmed distinction (location tag vs. endpoint tag are
# different security attributes, not the same one reused).
resource "oci_security_attribute_security_attribute" "vcn_scope" {
  provider                        = oci.home_region
  security_attribute_namespace_id = oci_security_attribute_security_attribute_namespace.basedb_ns.id
  name                             = "Network"
  description                      = "Tags the shared VCN so this policy's statements can scope to it."

  validator {
    validator_type = "ENUM"
    values         = [var.vcn_display_name]
  }
}

# --- The Base Database Service VM DB System itself ---
# Single-instance (node_count omitted/defaulted to 1).
#
# REAL BUG FOUND AND FIXED (first apply attempt): "VM.Standard.E5.Flex" --
# the AMD COMPUTE shape shown in MyLearn's own shape table -- is NOT a valid
# oci_database_db_system shape. The live API rejected it with a real 400
# InvalidParameter ("shape Invalid db system shape VM.Standard.E5.Flex").
# DB System shapes are a SEPARATE namespace from compute instance shapes --
# confirmed via `oci db system-shape list --compartment-id ... --region
# us-phoenix-1`, which returned only Exadata*/ExadataCC*/VM.BaseDB.x86/
# ExaDbXS -- no VM.Standard.* entries at all. The correct VM DB System shape
# is "VM.BaseDB.x86". Its shape-shape entry also reports
# compute-model=ECPU, minimum-core-count=4, core-count-increment=4 -- so
# cpu_core_count was bumped from 2 to 4 (the actual minimum for this shape)
# to match, not just the shape string.
resource "oci_database_db_system" "basedb" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_id            = var.private_subnet_id
  shape                = "VM.BaseDB.x86"
  hostname             = "basedblab"
  ssh_public_keys      = [var.ssh_public_key]
  display_name          = "basedb-lab-system"

  # REAL BUG FOUND AND FIXED (second apply attempt): compute_model is
  # "optional, computed" per the provider schema, so it was left unset --
  # but the live API rejected that with a real 400 InvalidParameter
  # ("Invalid computeModel null for shape VM.BaseDB.x86"). "Computed"
  # apparently means the API returns a value after the fact, not that it
  # will infer one for you on create. `oci db system-shape list` reports
  # compute-model=ECPU for VM.BaseDB.x86, so set explicitly here.
  compute_model            = "ECPU"
  # REAL BUG FOUND AND FIXED (third apply attempt): with compute_model set
  # to ECPU, cpu_core_count alone was not enough -- live API rejected with
  # a real 400 InvalidParameter ("computeCount cannot be null"). ECPU-based
  # shapes take their core count via the SEPARATE `compute_count` argument,
  # not the legacy OCPU-era `cpu_core_count` -- both exist on the provider
  # schema as distinct optional/computed number attributes; only one
  # actually applies depending on compute_model. Set compute_count to 4
  # (VM.BaseDB.x86's minimum-core-count / min-core-count-per-node from
  # `oci db system-shape list`) and dropped cpu_core_count entirely.
  compute_count            = 4
  data_storage_size_in_gb = 256 # minimum practical size for a study lab, well under the 80TB ceiling
  database_edition        = "STANDARD_EDITION" # cheapest licensed edition -- this is a study lab, not a production sizing exercise
  license_model            = "LICENSE_INCLUDED" # no BYOL complexity for a lab stack
  node_count                = 1
  disk_redundancy           = "NORMAL"
  # Matches the Console's own default (real screenshot: "Higher performance"
  # was NOT selected by default -- "Recommended choice for most workloads"
  # is "Balanced") -- a study lab has no I/O-demanding workload to justify
  # Higher performance's extra cost.
  storage_volume_performance_mode = "BALANCED"

  # storage_management ("LVM" vs. "ASM"/Oracle Grid Infrastructure) is a
  # REAL BUG FOUND AND FIXED here: `terraform validate` rejected it as a
  # top-level argument on oci_database_db_system -- confirmed via
  # `terraform providers schema` that it's actually nested one level down,
  # inside a db_system_options block. LVM matches the Console's own
  # recommended default ("Recommended for quick deployments using Logical
  # Volume Manager") -- see Note 6's LVM-vs-ASM section for the DATA/RECO
  # disk-group tradeoff this sidesteps.
  db_system_options {
    storage_management = "LVM"
  }

  nsg_ids = [oci_core_network_security_group.basedb_nsg.id]

  # ZPR applied directly to the DB SYSTEM resource -- security_attributes is
  # a genuine top-level attribute on oci_database_db_system (confirmed via
  # `terraform providers schema`), the same map(string) shape lab-zpr-stack
  # uses on oci_core_instance. Both .value AND .mode are required per
  # lab-zpr-stack's own confirmed finding (a real 400 "missing a required
  # key Optional[mode]" on first apply there) -- applying that same lesson
  # here without re-discovering it.
  security_attributes = {
    "${oci_security_attribute_security_attribute_namespace.basedb_ns.name}.${oci_security_attribute_security_attribute.db_role.name}.value" = "sensitive"
    "${oci_security_attribute_security_attribute_namespace.basedb_ns.name}.${oci_security_attribute_security_attribute.db_role.name}.mode"  = "enforce"
  }

  db_home {
    db_version   = var.db_version
    display_name = "basedb-lab-dbhome"

    database {
      db_name        = var.db_name
      admin_password = var.db_admin_password
      # STANDARD_EDITION doesn't support db_workload OLTP/DSS differentiation
      # the way Autonomous's ATP/ADW split does at the service level -- see
      # Note 6's "two independent axes" section for that Autonomous-specific
      # distinction, deliberately not replicated here since Base Database
      # Service's workload shaping happens at the schema/application layer,
      # not as a top-level provisioning choice like Autonomous.
    }
  }
}

# --- The ZPR policy: only db-client-tagged endpoints may reach
# sensitive-tagged endpoints, on the DB listener port, independent of
# whatever the NSG says -- same "holds even if the network-layer control is
# later loosened" property lab-zpr-stack's SSH lockdown demonstrates, applied
# to a database instead of SSH.
resource "oci_zpr_zpr_policy" "db_access_lockdown" {
  provider       = oci.home_region
  compartment_id = var.tenancy_ocid
  name           = "basedb-lab-access-policy"
  description    = "Allow only db-client-tagged endpoints to reach the sensitive-tagged database, independent of NSG state."

  statements = [
    "in ${oci_security_attribute_security_attribute_namespace.basedb_ns.name}.${oci_security_attribute_security_attribute.vcn_scope.name}:${var.vcn_display_name} VCN allow ${oci_security_attribute_security_attribute_namespace.basedb_ns.name}.${oci_security_attribute_security_attribute.db_role.name}:db-client endpoints to connect to ${oci_security_attribute_security_attribute_namespace.basedb_ns.name}.${oci_security_attribute_security_attribute.db_role.name}:sensitive endpoints with protocol='tcp/${var.db_listener_port}'"
  ]

  depends_on = [data.oci_zpr_configuration.tenancy_onboarding]
}
