variable "compartment_ocid" { type = string }
variable "tenancy_ocid" { type = string }
variable "vcn_id" { type = string }
variable "subnet_id" { type = string }
variable "ssh_public_key" { type = string }
# Restrict SSH to your own IP, matching the AWS deploy README's security
# group guidance ("22 restricted to your own IP"). Use "<your-ip>/32".
variable "ssh_allowed_cidr" { type = string }
variable "region" {
  type    = string
  default = "us-phoenix-1"
}

# Search terms seeded into /opt/magnetlookup/data/search_term.txt at boot,
# replacing setup.sh's own placeholder default. One heading per line group,
# e.g. "[Software]\nUbuntu 24.04" — same [Section]/term format the app's
# search_term.txt already uses.
variable "search_terms" {
  type    = string
  default = <<-EOT
    [Software]
    Ubuntu 24.04

    [Books]
    Polymer Materials
  EOT
}

# Populates /etc/magnetlookup/env's MAGNET_S3_BUCKET-equivalent config at
# boot. Left blank by default since backup_to_s3.sh (AWS CLI-based) hasn't
# been ported to OCI yet — see LABS.md's lab-mymagnet-stack entry. Setting
# this now doesn't enable backups on its own; the backup timer unit isn't
# installed by this stack.
variable "backup_bucket_name_override" {
  type    = string
  default = ""
}
