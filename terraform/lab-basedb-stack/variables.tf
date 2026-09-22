variable "compartment_ocid" { type = string }
variable "tenancy_ocid" { type = string }
variable "vcn_id" { type = string }

# The VCN's own display_name -- needed as a plain string (not just its OCID)
# for the ZPR "vcn_scope" security attribute's ENUM validator, which tags the
# VCN by name for the policy's "in <location> VCN" clause. Must match
# lab-network-stack's oci_core_vcn.lab_vcn.display_name exactly.
variable "vcn_display_name" { type = string }

variable "private_subnet_id" { type = string }

variable "region" {
  type    = string
  default = "us-phoenix-1"
}

# IAM writes (ZPR configuration, security attribute namespace/attribute,
# ZPR policy) are all home-region-only -- same rule lab-zpr-stack confirmed.
variable "home_region" {
  type        = string
  description = "Tenancy home region -- required for ZPR/security-attribute resources, which are CREATE/UPDATE/DELETE-in-home-region-only per the OCI API."
}

variable "ssh_public_key" { type = string }

# Restrict DB listener access to a known source, matching the pattern used
# for SSH elsewhere in this repo's labs -- use "<your-ip>/32".
variable "db_client_allowed_cidr" { type = string }

variable "db_listener_port" {
  type    = number
  default = 1521 # standard Oracle Net listener port
}

variable "db_version" {
  type        = string
  description = "Oracle Database version for db_home (e.g. \"19.0.0.0\") -- pass explicitly rather than defaulting, since valid values depend on the image catalog at apply time; verify against `oci db version list --db-system-shape ...` for the target shape/region before applying."
}

variable "db_name" {
  type    = string
  default = "basedblb"
}

# No default -- OCI Database's own password complexity rules (9-30 chars,
# at least one uppercase, one lowercase, one number, no username substring)
# make a placeholder default actively unsafe to leave in place unnoticed.
# Pass via -var, not committed anywhere.
#
# REAL BUGS FOUND AND FIXED (fourth and fifth apply attempts):
# 1) An alphanumeric-only password (no special characters, chosen to
#    sidestep shell-escaping) was rejected by the live API with a real 400
#    InvalidParameter ("The database admin password should contain at
#    least two special characters") -- so Base Database Service's actual
#    complexity floor is stricter than the commonly-quoted "9-30 chars,
#    upper/lower/digit, no username substring" rule above: it also
#    requires >= 2 special characters.
# 2) The next attempt, using #_-%^&+ as the special-character pool, was
#    ALSO rejected -- a different real 400 InvalidParameter this time:
#    "The database admin password should contain only: alphanumeric,
#    hyphen(-), underscore(_), pound(#)." So the allowed special-character
#    set is much narrower than typical password-complexity rules: ONLY
#    -, _, and # -- not the broader set assumed above. Fixed by generating
#    a password using just those three, which is also conveniently
#    shell-safe (no $, backticks, or quotes).
variable "db_admin_password" {
  type      = string
  sensitive = true
}
