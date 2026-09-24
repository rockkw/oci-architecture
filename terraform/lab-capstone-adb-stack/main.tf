terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

provider "oci" {
  region = var.region
}

# IAM writes go to the home region -- same rule lab-mymagnet-stack and
# lab-storage-stack hit (403 outside the home region).
provider "oci" {
  alias  = "home"
  region = var.home_region
}

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}

# --- Why not Always Free? ---
# Always Free ADB was considered and rejected. Per Oracle's Always Free docs:
#   * it can only be created in the HOME region (us-ashburn-1), while
#     MyMagnet runs in us-phoenix-1;
#   * it "cannot be provisioned as a private endpoint and cannot reside
#     within a VCN", so the app would reach it over the public internet
#     (NAT gateway -> public ADB endpoint in another region, allowed by an
#     ACL on the NAT's public IP);
#   * it stops after 7 days without activity and can be reclaimed after 90.
# The exam-relevant pattern here is the private endpoint + NSG, so this
# stack pays for the smallest paid database instead (2 ECPUs, 20 GB,
# no auto-scaling). Stop it when not studying:
#   oci db autonomous-database stop --autonomous-database-id <id>
# Stopped ADB bills storage only.

# --- NSG: the listener, from the instance subnet only ---
resource "oci_core_network_security_group" "adb" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "mymagnet-adb-nsg"
}

# 1522 only. Oracle's private-endpoint docs: mTLS uses 1522; TLS
# (walletless) accepts 1521 OR 1522. Using 1522 for TLS too means one port
# works whether or not mTLS is later re-required, and 1521 stays closed.
# No egress rule: NSG rules are stateful, so replies to these connections
# are allowed without one. Phase 4 (Select AI -> vLLM with
# ROUTE_OUTBOUND_CONNECTIONS) will need an egress rule to the internal LB.
resource "oci_core_network_security_group_security_rule" "ingress_listener" {
  network_security_group_id = oci_core_network_security_group.adb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.instance_subnet_cidr
  source_type               = "CIDR_BLOCK"
  stateless                 = false
  tcp_options {
    destination_port_range {
      min = 1522
      max = 1522
    }
  }
}

# --- Passwords: generated, stored in Vault ---
# ADB ADMIN rules (Oracle docs): 12-30 chars, >= 1 upper, 1 lower, 1 digit,
# no double quote, must not contain "admin". lab-basedb-stack learned the
# hard way that Base DB only accepts - _ # as specials; ADB's documented
# rule is looser, but the same three are kept here because they are also
# shell- and DSN-safe.
resource "random_password" "admin" {
  length           = 20
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "-_#"
}

# Password for the MAGNET schema the app uses. The app never logs in as
# ADMIN; sql/01_create_app_user.sql creates this user.
resource "random_password" "app" {
  length           = 20
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "-_#"
}

# Vault secrets must be encrypted with an AES key. lab-mymagnet-stack's
# only key (mymagnet-cert-key) is RSA -- it was made for the private CA --
# so it can't be used here. New AES-256 key in the same Vault.
# length is in BYTES: 32 = AES-256.
resource "oci_kms_key" "secrets" {
  compartment_id      = var.compartment_ocid
  display_name        = "mymagnet-secrets-key"
  management_endpoint = var.vault_management_endpoint

  key_shape {
    algorithm = "AES"
    length    = 32
  }
}

resource "oci_vault_secret" "adb_admin" {
  compartment_id = var.compartment_ocid
  vault_id       = var.vault_id
  key_id         = oci_kms_key.secrets.id
  secret_name    = "mymagnet-adb-admin-password"
  description    = "ADMIN password for the MyMagnet Autonomous Database"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(random_password.admin.result)
  }
}

resource "oci_vault_secret" "adb_app" {
  compartment_id = var.compartment_ocid
  vault_id       = var.vault_id
  key_id         = oci_kms_key.secrets.id
  secret_name    = "mymagnet-adb-app-password"
  description    = "Password for the MAGNET schema the MyMagnet app connects as"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(random_password.app.result)
  }
}

# --- The database ---
resource "oci_database_autonomous_database" "mymagnet" {
  compartment_id = var.compartment_ocid
  db_name        = var.db_name
  display_name   = "mymagnet-adb"
  db_workload    = "OLTP" # Transaction Processing: row-at-a-time app writes
  db_version     = var.db_version
  license_model  = "LICENSE_INCLUDED"
  is_free_tier   = false # see "Why not Always Free?" above

  compute_model           = "ECPU"
  compute_count           = var.compute_count
  data_storage_size_in_gb = var.data_storage_size_in_gb

  # Keep the bill fixed: auto-scaling can triple ECPUs under load.
  is_auto_scaling_enabled             = false
  is_auto_scaling_for_storage_enabled = false

  # The ADMIN password comes from the Vault secret, not a plain argument,
  # so it isn't copied into this resource's arguments. The caller (whoever
  # runs terraform apply) needs "read secret-bundles" on it -- true for an
  # Administrators-group user. random_password.admin.result is still in
  # this stack's state; state is local and gitignored.
  secret_id = oci_vault_secret.adb_admin.id

  # Private endpoint in the instance subnet. No public endpoint, no ACL.
  subnet_id              = var.instance_subnet_id
  nsg_ids                = [oci_core_network_security_group.adb.id]
  private_endpoint_label = "mymagnetadb"

  # TLS without a wallet, so python-oracledb thin mode needs only a
  # user/password/DSN. Oracle requires mTLS unless the database has an ACL
  # or a private endpoint; with a private endpoint it may be turned off.
  is_mtls_connection_required = false
}

# --- Bucket for the ONNX embedding model ---
# Oracle ships all_MiniLM_L12_v2 as a zip. DBMS_VECTOR.LOAD_ONNX_MODEL_CLOUD
# reads a single .onnx object, so the file has to be unzipped and put in a
# bucket first. A pre-authenticated request (PAR) on that one object lets
# the load run with credential => NULL (per Oracle's LOAD_ONNX_MODEL_CLOUD
# docs), avoiding a resource-principal credential and its IAM policy.
# DBMS_CLOUD traffic isn't routed through the private endpoint unless
# ROUTE_OUTBOUND_CONNECTIONS = ENFORCE_PRIVATE_ENDPOINT is set, so the load
# reaches Object Storage without any VCN change. The upload and the PAR
# are manual steps (sql/README.md): the PAR needs the object to exist.
resource "oci_objectstorage_bucket" "models" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "mymagnet-onnx-models"
  access_type    = "NoPublicAccess"
}

# --- IAM: instances may read the app password ---
# Lets MyMagnet's instances (lab-mymagnet-stack's existing dynamic group)
# fetch the MAGNET password at boot with instance-principal auth, instead
# of the password being copied into cloud-init or a committed file.
# Scoped to the one secret by name.
resource "oci_identity_policy" "adb_secret_read" {
  provider       = oci.home
  compartment_id = var.compartment_ocid
  name           = "mymagnet-adb-secret-read"
  description    = "Let MyMagnet instances read the ADB app-user password from Vault"

  statements = [
    "Allow dynamic-group ${var.instance_dynamic_group_name} to read secret-bundles in compartment id ${var.compartment_ocid} where target.secret.name = '${oci_vault_secret.adb_app.secret_name}'",
  ]
}
