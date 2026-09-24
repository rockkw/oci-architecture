variable "compartment_ocid" { type = string }
variable "tenancy_ocid" { type = string }
variable "vcn_id" { type = string }
# No longer referenced by any resource as of the Blocker 2 fix below (see
# var.instance_subnet_id) — the backend instances moved to that variable's
# NAT-routed subnet instead, since this one (the original public/IGW-routed
# lab-subnet) can't provide egress for a VNIC with assign_public_ip = false.
# Left declared, not removed, so any existing tfvars/CI invocation that
# still passes -var subnet_id=... doesn't hard-fail; harmless if unused.
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

# REAL BUG FOUND (Blocker 2 investigation, see LABS.md): var.subnet_id (the
# backend instances' subnet, originally lab-network-stack's "lab-subnet")
# routes 0.0.0.0/0 to an Internet Gateway. IGW egress in OCI only works for
# VNICs that themselves hold a public IP — but the 2-node/LB redesign set
# assign_public_ip = false on both backend instances (main.tf), so they have
# NO route to the internet at all. Confirmed live via console-history: the
# very first cloud-init runcmd step, `git clone
# https://github.com/rockkw/MyMagnet.git`, failed after 136s with "Failed to
# connect to github.com port 443 ... Network is unreachable", cascading to
# every downstream step (setup.sh never existed to sed/run, nginx never
# installed) — this is why the LB health check sees CONNECT_FAILED on port
# 80: nginx was never started, not an NSG/iptables/awscli problem. (The
# iptables ACCEPT rules for 80/443 DID apply successfully in the same boot,
# confirmed by `netfilter-persistent save` running right after the failed
# clone — cloud-init's runcmd has no set -e, so later steps still ran.)
#
# Fix: give the backend instances their own subnet variable, separate from
# lb_subnet_id (which must keep IGW/public-IP-capable routing, since the LB
# itself needs internet reachability), pointed at a NAT-Gateway-routed
# private subnet instead. lab-private-network-stack (already applied in
# this repo) provisions exactly this: its private_subnet_id output
# (10.0.2.0/24, route table -> oci_core_nat_gateway) is a live, real OCID —
# ocid1.subnet.oc1.phx.aaaaaaaag4oejcez5n7w77ixbt7qchi35wjulh7ear7o3htwkssroxo74b5a
# as of this writing. NOT auto-applied here: moving var.subnet_id's value
# forces replacement of both oci_core_instance resources (subnet_id isn't
# mutable in-place), which means new private IPs, updated
# oci_load_balancer_backend resources, and fresh (empty) per-instance
# SQLite state — a real, visible change to currently-running infrastructure
# that goes beyond "restart a service," so it's left for explicit
# human-in-the-loop apply rather than run autonomously. See LABS.md for the
# full writeup.
variable "instance_subnet_id" {
  type        = string
  description = "NAT-routed private subnet for the backend instances (e.g. lab-private-network-stack's private_subnet_id) — must be different from lb_subnet_id, which needs IGW/public-IP-capable routing for the LB itself."
}

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
