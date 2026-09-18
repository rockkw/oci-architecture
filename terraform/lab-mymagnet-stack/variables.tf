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

# --- Added for the LB + 2-node + OCI Certificates redesign (DESIGN ONLY,
# not yet applied — see LABS.md) ---

# Subnet the LB itself lives in. Separate from var.subnet_id (the backend
# instances' subnet) to match lab-lb-stack/lab-firewall-stack's pattern in
# this repo of the LB having its own subnet — pass the same OCID as
# var.subnet_id if a single-subnet layout is preferred instead, OCI doesn't
# require them to differ.
variable "lb_subnet_id" { type = string }

# CIDR of the LB's subnet, used only in the mymagnet NSG's ingress rule so
# the backend port is reachable from the LB but not from 0.0.0.0/0 directly.
# Kept as a separate variable rather than derived from lb_subnet_id, since
# this stack (matching its existing style) takes subnet identity as input
# rather than looking up a data.oci_core_subnet for its CIDR.
variable "lb_subnet_cidr" { type = string }

# Port the LB's backend set/health checker hits on each instance.
# UNVERIFIED — see the flagged comment on oci_load_balancer_backend_set.
# mymagnet in main.tf. 80 confirmed directly against the live instance
# before tearing it down for this redesign: `curl -o /dev/null -w '%{http_code}'
# http://<public_ip>/` returned 200; the same check against 443 and 8080
# both timed out (443 not actually serving TLS despite the NSG allowing it —
# Certbot apparently never ran on this instance; 8080 is MAGNET_PORT,
# webserver.py's own bind, 127.0.0.1-only per the original NSG comment, not
# externally reachable). No longer a guess.
variable "backend_port" {
  type    = number
  default = 80
}

# Common name (CN) for the OCI Certificates leaf cert and its issuing CA's
# subject — should match the DNS A record the Reserved Public IP
# (oci_core_public_ip.mymagnet) resolves to, same as the original single-
# instance design's implied Certbot CN would have.
variable "cert_common_name" { type = string }

# RFC3339 expiry for both the CA and leaf cert's validity block — a static
# literal, NOT computed via timeadd(timestamp(), ...) inside main.tf
# (timestamp() is unknown at plan time, which is its own separate problem
# worth avoiding here regardless of the finding below).
#
# REAL BUG, confirmed by bisecting against the raw API directly (bypassing
# Terraform and the OCI CLI's SDK wrapper) after the generic
# 400-InvalidParameter "Unable to process JSON input" error survived a
# provider upgrade (9.1.0 -> 9.2.0) and a `timestamp()` removal: OCI
# Certificates Management's timeOfValidityNotAfter requires MILLISECOND
# precision. `2027-09-18T17:14:17Z` (bare seconds, otherwise fully valid
# RFC3339) is silently rejected; `2027-09-18T17:14:17.000Z` (explicit
# .000 milliseconds) is accepted. Omitting the validity block entirely also
# works — the API defaults it to a ~10-year-out expiry — which is how this
# was isolated: a minimal payload without `validity` succeeded, and adding
# the exact same date string back in immediately reintroduced the failure,
# regardless of Z vs +00:00 offset notation (both fail without milliseconds;
# both succeed with them). Not documented as a hard requirement anywhere in
# the provider docs or CLI's own generated example values used to build this
# stack's original (also millisecond-less) date. Compute a real value with
# explicit milliseconds (e.g. `date -u -v+1y +"%Y-%m-%dT%H:%M:%S.000Z"` on
# macOS) and pass it as -var.
variable "cert_valid_until" { type = string }
