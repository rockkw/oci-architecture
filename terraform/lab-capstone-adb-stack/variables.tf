variable "compartment_ocid" { type = string }
variable "tenancy_ocid" { type = string }

# Same VCN as lab-mymagnet-stack (lab-network-stack's lab-vcn). The NSG has
# to live in the VCN the private endpoint lives in.
variable "vcn_id" { type = string }

# lab-private-network-stack's private_subnet_id (10.0.2.0/24, NAT-routed):
# the same subnet the two MyMagnet instances use. The ADB private endpoint
# goes here too, so app -> DB traffic never leaves the subnet and no route
# table or security list change is needed.
variable "instance_subnet_id" { type = string }

# Only this CIDR may reach the listener. Taken as a string rather than read
# from a data.oci_core_subnet, matching lab-mymagnet-stack's lb_subnet_cidr.
variable "instance_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "region" {
  type    = string
  default = "us-phoenix-1"
}

# IAM (the secret-read policy) is written in the home region only.
variable "home_region" {
  type    = string
  default = "us-ashburn-1"
}

# lab-mymagnet-stack's oci_kms_vault.mymagnet. Passed in, not looked up,
# per this repo's "dependencies come in as variables" rule. Get both with:
#   oci kms management vault list -c <compartment> --region us-phoenix-1
variable "vault_id" { type = string }
variable "vault_management_endpoint" { type = string }

# lab-mymagnet-stack's dynamic group name; the policy below lets these
# instances read the app user's password from Vault.
variable "instance_dynamic_group_name" {
  type    = string
  default = "mymagnet-instance-dyn-grp"
}

# "26ai" is what `oci db autonomous-db-version list --db-workload OLTP`
# returned as is-default-for-paid in us-phoenix-1 on 2026-09-24; "23ai" and
# "19c" were still listed. Oracle's docs now call the service "Autonomous
# AI Database". AI Vector Search (VECTOR type, VECTOR_EMBEDDING, vector
# indexes) needs 23ai or later; 19c won't work.
variable "db_version" {
  type    = string
  default = "26ai"
}

# ADB db_name: letters and digits only, starting with a letter.
variable "db_name" {
  type    = string
  default = "mymagnet"
}

# ECPU minimum for Autonomous Database Serverless is 2.
variable "compute_count" {
  type    = number
  default = 2
}

# 20 GB is the smallest data_storage_size_in_gb the ECPU model accepts.
# The library is a few MB of text plus 384-float vectors (~1.5 KB per row),
# so this is far more than needed.
variable "data_storage_size_in_gb" {
  type    = number
  default = 20
}
