terraform {
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

# IAM writes (dynamic group, policy) go to the tenancy's home region — see
# lab-storage-stack, which hit this as a hard 403 outside the home region.
provider "oci" {
  alias  = "home"
  region = "us-ashburn-1"
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Ubuntu 24.04, matching the AWS deploy README's stated OS (setup.sh is
# apt-get-based and was written/tested against this version specifically).
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}

# --- DESIGN-ONLY CHANGE (not yet applied) ---
# Originally a single instance with the Reserved Public IP directly on its
# VNIC. Restructured to 2 backend instances behind an OCI Load Balancer,
# per the user's explicit decision to accept the local-SQLite data-
# consistency risk (no shared DB/storage across instances — see
# cloud-init.yaml.tftpl's MAGNET_DB_FILE comment) in exchange for sticky
# sessions on the LB backend set, rather than solving real data replication.
# See terraform/LABS.md's lab-mymagnet-stack section for the full rationale.
#
# NSG now mirrors the LB-fronted topology instead of the AWS README's
# original single-instance guidance: 80/443 are OPEN ON THE LB ITSELF (via
# its own listeners, not this NSG), NOT on the instances directly anymore.
# The instances are only reachable from the LB subnet on the backend port,
# plus SSH from var.ssh_allowed_cidr as before. webserver.py still binds to
# 127.0.0.1 only; nginx is still each instance's local entry point, but the
# LB is now the sole *public* entry point.
resource "oci_core_network_security_group" "mymagnet" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "mymagnet-nsg"
}

# Backend port reachable only from the LB subnet, not 0.0.0.0/0. Source CIDR
# here is var.lb_subnet_cidr rather than the LB's own IP, since NSG rules
# match on subnet/CIDR, not on a specific resource's private IP that isn't
# known until after the LB is created (and OCI LB private IPs aren't a
# stable Terraform-time value to reference here anyway).
resource "oci_core_network_security_group_security_rule" "ingress_backend_from_lb" {
  network_security_group_id = oci_core_network_security_group.mymagnet.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.lb_subnet_cidr
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = var.backend_port
      max = var.backend_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "ingress_ssh" {
  network_security_group_id = oci_core_network_security_group.mymagnet.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.ssh_allowed_cidr
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "egress_all" {
  network_security_group_id = oci_core_network_security_group.mymagnet.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# LB's own NSG: 80/443 open publicly, since the LB (not the instances) is
# now the public entry point. Kept as a separate NSG from mymagnet's, mainly
# because oci_load_balancer_load_balancer's network_security_group_ids
# attaches at the LB level, not the VNIC level like oci_core_instance does.
resource "oci_core_network_security_group" "mymagnet_lb" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "mymagnet-lb-nsg"
}

resource "oci_core_network_security_group_security_rule" "lb_ingress_http" {
  network_security_group_id = oci_core_network_security_group.mymagnet_lb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_ingress_https" {
  network_security_group_id = oci_core_network_security_group.mymagnet_lb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_egress_all" {
  network_security_group_id = oci_core_network_security_group.mymagnet_lb.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# Two explicitly-named backend instances (not count/for_each — matching
# this file's existing style, and lab-firewall-stack's web_server_1/
# web_server_2 pattern in this same repo) rather than a single instance.
# Both are independent, functionally-duplicate MyMagnet installs: same
# cloud-init, same repo clone, own local SQLite DB
# (MAGNET_DB_FILE=/opt/magnetlookup/data/magnet_library.db per cloud-
# init.yaml.tftpl) with NO replication between them. Acceptable per the
# user's explicit sticky-sessions decision above — a given client always
# lands on the same backend via the LB's session_persistence_configuration
# below, so it always sees its own instance's SQLite state.
resource "oci_core_instance" "mymagnet_1" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "mymagnet-instance-1"
  shape               = "VM.Standard.A1.Flex"

  # AWS README sizes this at EC2 t4g.small (2 vCPU/2GB burstable ARM) —
  # OCI's closest equivalent shape/size for "single daily scrape job plus a
  # low-traffic dashboard." Same sizing per node now that there are two.
  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  create_vnic_details {
    subnet_id = var.subnet_id
    # No public IP on either instance anymore — the LB is the only public
    # entry point now. The Reserved Public IP (oci_core_public_ip.mymagnet
    # below) moved from fronting this instance directly to fronting the LB
    # instead, via the LB's reserved_ips block.
    assign_public_ip = false
    nsg_ids          = [oci_core_network_security_group.mymagnet.id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
      search_terms       = var.search_terms
      backup_bucket_name = var.backup_bucket_name_override
    }))
  }
}

resource "oci_core_instance" "mymagnet_2" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "mymagnet-instance-2"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = false
    nsg_ids          = [oci_core_network_security_group.mymagnet.id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    # Same search_terms/backup_bucket_name as instance 1 — both nodes run
    # identical config. If per-node search terms are ever wanted, this is
    # the templatefile() call to diverge.
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
      search_terms       = var.search_terms
      backup_bucket_name = var.backup_bucket_name_override
    }))
  }
}

# Reserved Public IP — previously assigned directly to the single
# instance's primary private IP; now assigned to the LB instead (see
# oci_load_balancer_load_balancer.mymagnet's reserved_ips block below), so
# it keeps being the stable, stop/start-surviving IP for the DNS A record
# the README's TLS step needs, just one hop further out than before.
resource "oci_core_public_ip" "mymagnet" {
  compartment_id = var.compartment_ocid
  lifetime       = "RESERVED"
  display_name   = "mymagnet-reserved-ip"
  # No private_ip_id here (unlike the old single-instance version of this
  # resource) — that argument is only for attaching the Reserved IP to a
  # specific private IP at creation time. Standalone RESERVED public IPs are
  # created unattached and then attached elsewhere; the LB's reserved_ips
  # block below does that attachment by referencing this resource's id,
  # matching how oci_load_balancer_load_balancer's docs show reusing a
  # pre-existing Reserved IP instead of provisioning a new ephemeral one.
}

# --- Load Balancer: the new (and now only) public entry point ---
# Replaces the old instance-direct Reserved IP. subnet_ids takes
# var.lb_subnet_id rather than var.subnet_id (the backend instances'
# subnet) — this stack follows lab-lb-stack/lab-firewall-stack's pattern of
# the LB living in its own subnet, separate from the compute tier, rather
# than sharing one. If this stack is applied standalone with the LB and
# instances in the SAME subnet, pass the same OCID for both variables; that
# works too (OCI doesn't require separate subnets), it's just not what the
# sibling labs in this repo do.
resource "oci_load_balancer_load_balancer" "mymagnet" {
  compartment_id             = var.compartment_ocid
  display_name               = "mymagnet-lb"
  shape                      = "flexible"
  subnet_ids                 = [var.lb_subnet_id]
  network_security_group_ids = [oci_core_network_security_group.mymagnet_lb.id]

  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 100
  }

  # Reuses the Reserved Public IP that used to sit directly on the
  # instance's VNIC, instead of letting the LB provision its own ephemeral
  # public IP — keeps the same stable IP for the existing DNS A record.
  reserved_ips {
    id = oci_core_public_ip.mymagnet.id
  }
}

# Backend set with session persistence (sticky sessions) enabled, per the
# user's explicit decision to run 2 independent-SQLite-state backends
# rather than solve real data replication: a client's session cookie pins
# it to whichever backend it first landed on, so repeat requests keep
# seeing that backend's local DB/results instead of bouncing between two
# instances with different data.
#
# session_persistence_configuration (application-cookie stickiness) vs.
# lb_cookie_session_persistence_configuration (LB-generated cookie) are
# mutually exclusive per the provider's own docs — using
# session_persistence_configuration here since it lets the LB detect a
# cookie the backend itself sets, which fits a normal Flask/nginx session
# cookie without requiring extra backend-side config. cookie_name is
# REQUIRED on this block per the provider schema (confirmed against the
# provider's website docs); using "*" ("any cookie set by the backend")
# rather than a specific name, since it's not confirmed here whether
# webserver.py sets a named session cookie at all — flagged below.
resource "oci_load_balancer_backend_set" "mymagnet" {
  name             = "mymagnet-backend-set"
  load_balancer_id = oci_load_balancer_load_balancer.mymagnet.id
  policy           = "ROUND_ROBIN"

  session_persistence_configuration {
    cookie_name      = "*"
    disable_fallback = false
  }

  # Health check port: CONFIRMED against the live instance before this
  # redesign was applied. `curl http://<public_ip>/` (port 80) returned
  # HTTP 200; the same check against 443 and 8080 both timed out — 443 isn't
  # actually serving TLS despite the NSG allowing it (Certbot apparently
  # never ran), and 8080 is MAGNET_PORT, webserver.py's own 127.0.0.1-only
  # bind, never externally reachable. nginx's plain-HTTP listener on 80 is
  # the real, confirmed entry point setup.sh configures.
  health_checker {
    protocol = "HTTP"
    port     = var.backend_port
    url_path = "/"
  }
}

resource "oci_load_balancer_backend" "mymagnet_1" {
  load_balancer_id = oci_load_balancer_load_balancer.mymagnet.id
  backendset_name  = oci_load_balancer_backend_set.mymagnet.name
  ip_address       = oci_core_instance.mymagnet_1.private_ip
  port             = var.backend_port
}

resource "oci_load_balancer_backend" "mymagnet_2" {
  load_balancer_id = oci_load_balancer_load_balancer.mymagnet.id
  backendset_name  = oci_load_balancer_backend_set.mymagnet.name
  ip_address       = oci_core_instance.mymagnet_2.private_ip
  port             = var.backend_port
}

resource "oci_load_balancer_listener" "mymagnet_http" {
  name                     = "mymagnet-http-listener"
  load_balancer_id         = oci_load_balancer_load_balancer.mymagnet.id
  default_backend_set_name = oci_load_balancer_backend_set.mymagnet.name
  port                     = 80
  protocol                 = "HTTP"
}

resource "oci_load_balancer_listener" "mymagnet_https" {
  name                     = "mymagnet-https-listener"
  load_balancer_id         = oci_load_balancer_load_balancer.mymagnet.id
  default_backend_set_name = oci_load_balancer_backend_set.mymagnet.name
  port                     = 443
  protocol                 = "HTTP"

  # certificate_ids (not the legacy certificate_name/inline-PEM pattern) is
  # the argument for attaching an OCI Certificates service-managed
  # certificate to an LB listener — confirmed against the provider's
  # website docs for oci_load_balancer_listener's ssl_configuration block,
  # which documents certificate_ids as "Ids for Oracle Cloud Infrastructure
  # certificates service certificates. Currently only a single Id may be
  # passed." certificate_name still exists on the same block for the older
  # inline-PEM-via-oci_load_balancer_certificate pattern, deliberately not
  # used here.
  ssl_configuration {
    certificate_ids         = [oci_certificates_management_certificate.mymagnet.id]
    verify_peer_certificate = false
    verify_depth            = 3
  }
}

# --- OCI Certificates: Vault, Master Encryption Key, private CA, leaf cert ---
# No existing oci_kms_vault/oci_kms_key found anywhere else in this repo
# (grepped terraform/ for oci_kms_vault and oci_certificates_* — no hits
# outside this stack), so this provisions the minimal Vault + Key needed
# rather than taking OCIDs as input variables. If a shared Vault already
# exists in the real tenant outside of what's tracked in this repo's
# Terraform, that's not visible here — this follows LABS.md's stated
# philosophy of stacks taking dependencies as input variables only when
# ANOTHER STACK IN THIS REPO provisions them; since none does for KMS/
# Certificates, provisioning fresh is the closer fit, not a violation of
# that philosophy.
resource "oci_kms_vault" "mymagnet" {
  compartment_id = var.compartment_ocid
  display_name   = "mymagnet-vault"
  vault_type     = "DEFAULT"
}

resource "oci_kms_key" "mymagnet" {
  compartment_id      = var.compartment_ocid
  display_name        = "mymagnet-cert-key"
  management_endpoint = oci_kms_vault.mymagnet.management_endpoint

  # length is in BYTES, not bits, and its valid values depend on algorithm:
  # RSA keys are 256/384/512 bytes (2048/3072/4096-bit), not raw AES-style
  # bit-count values. 256 bytes = 2048-bit RSA, matching the algorithm/
  # key-size pairing shown on MyLearn's own "Certificate Authority" slide
  # (RSA_2048 is the smallest of its two listed RSA options) rather than a
  # copy-pasted AES-256 length mismatched to RSA.
  key_shape {
    algorithm = "RSA"
    length    = 256
  }
}

# Private CA — ROOT_CA_GENERATED_INTERNALLY, matching the MyLearn scenario's
# "OCI Certificates" chain (Vault/Key -> CA -> leaf certificate -> LB
# listener) rather than an externally-issued or imported cert. Resource
# name confirmed as oci_certificates_management_certificate_authority
# against the provider's website docs (NOT oci_certificates_certificate_
# authority, which doesn't exist as a resource — only as a data source
# naming convention the prompt for this change guessed incorrectly).
resource "oci_certificates_management_certificate_authority" "mymagnet" {
  compartment_id = var.compartment_ocid
  name           = "mymagnet-ca"
  kms_key_id     = oci_kms_key.mymagnet.id

  certificate_authority_config {
    config_type = "ROOT_CA_GENERATED_INTERNALLY"

    subject {
      common_name = var.cert_common_name
    }

    # REAL BUG FOUND AND FIXED (see var.cert_valid_until in variables.tf for
    # the full story): OCI Certificates Management's timeOfValidityNotAfter
    # requires MILLISECOND precision — a bare-seconds RFC3339 value fails
    # with 400-InvalidParameter "Unable to process JSON input" even though
    # it's otherwise fully valid RFC3339. var.cert_valid_until must be
    # supplied with explicit .000 milliseconds (e.g.
    # 2027-09-18T17:24:03.000Z), confirmed by bisecting directly against the
    # real API (bypassing Terraform and the OCI CLI's SDK wrapper) since the
    # error message itself never named the actual field or format issue.
    validity {
      time_of_validity_not_after = var.cert_valid_until
    }
  }

  # BLOCKED, NOT YET RESOLVED — real, reproducible failure against this
  # exact key, confirmed multiple times: the CA reaches lifecycle_state
  # FAILED with lifecycle_details "Authorization failed or requested
  # resource not found: Key Id <this key's OCID>." This is NOT the
  # timestamp bug above (fixed and confirmed separately) — it reproduces
  # even with a fully correct, schema-valid payload sent directly to the
  # raw API (bypassing Terraform and the OCI CLI's own SDK wrapper).
  #
  # Two IAM policies were tried against the real tenancy and BOTH failed to
  # fix it, then were removed again (this stack's own oci_identity_policy
  # resource above is unrelated — these were separate, out-of-band policies
  # tested directly via `oci iam policy create`, never added to this file):
  #   1. Allow service certificates to use keys in compartment id <compartment>
  #   2. Allow service certificates to use key-delegate in compartment id <compartment>
  # (2) matches Oracle's own documented semantics for a service using a
  # customer's key on the customer's behalf (key-delegate, not keys) and
  # was expected to fix this — it did not. Both were given time to
  # propagate to the home region before retrying, ruling out a simple
  # propagation-delay explanation.
  #
  # vault_type = "DEFAULT" (see oci_kms_vault.mymagnet below) may itself be
  # the real blocker (untested: a VIRTUAL_PRIVATE/HSM-dedicated vault was
  # never tried) — or there's a policy clause/scoping this wasn't correct
  # yet (e.g. requiring `where target.key.id = '...'` rather than a
  # compartment-wide grant), or something else entirely. Root cause is
  # UNRESOLVED as of this comment. See terraform/LABS.md's lab-mymagnet-stack
  # entry for the full investigation writeup before spending more time here.
}

resource "oci_certificates_management_certificate" "mymagnet" {
  compartment_id = var.compartment_ocid
  name           = "mymagnet-cert"

  certificate_config {
    config_type                     = "ISSUED_BY_INTERNAL_CA"
    issuer_certificate_authority_id = oci_certificates_management_certificate_authority.mymagnet.id
    certificate_profile_type        = "TLS_SERVER_OR_CLIENT"

    subject {
      common_name = var.cert_common_name
    }

    # Same timestamp() fix as the CA above — see that resource's comment.
    validity {
      time_of_validity_not_after = var.cert_valid_until
    }
  }
}

# S3-equivalent for future backups (backup_to_s3.sh itself still needs
# porting to the oci CLI separately — this just provisions the bucket +
# IAM plumbing ahead of that, mirroring iam-policy-s3-backup.json's intent).
resource "oci_objectstorage_bucket" "backups" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "mymagnet-backups"
  access_type    = "NoPublicAccess"
}

resource "oci_identity_dynamic_group" "mymagnet_dyn_grp" {
  provider       = oci.home
  compartment_id = var.tenancy_ocid
  name           = "mymagnet-instance-dyn-grp"
  description    = "Matches both MyMagnet instances for resource-principal access to their shared backup bucket"
  # ANY {...} rather than ALL {...} — this must match EITHER instance
  # individually (each instance authenticates as itself via its own
  # instance principal on its own request), not require both conditions to
  # hold simultaneously. A single ANY{} block with multiple instance.id
  # clauses is OCI's documented pattern for "match any of these specific
  # resources" — same structure Oracle's own docs show for matching
  # multiple instance.compartment.id values ("Any {instance.compartment.id
  # = 'ocid1...', instance.compartment.id = 'ocid1...'}"), applied here to
  # instance.id instead. Using instance.id (not resource.id, which the
  # original single-instance rule used) to match Oracle's own documented
  # attribute name for this exact use case — resource.id / resource.type
  # also work per the provider's examples elsewhere, but instance.id is
  # what Oracle's dynamic-group matching-rule docs use in the multi-
  # instance ANY{} example specifically, so switching to match it exactly.
  matching_rule = "ANY {instance.id = '${oci_core_instance.mymagnet_1.id}', instance.id = '${oci_core_instance.mymagnet_2.id}'}"
}

resource "oci_identity_policy" "mymagnet_policy" {
  provider       = oci.home
  compartment_id = var.compartment_ocid
  name           = "mymagnet-backup-policy"
  description    = "Allow both MyMagnet instances to read/write the shared backup bucket via instance principal"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.mymagnet_dyn_grp.name} to manage objects in compartment id ${var.compartment_ocid} where target.bucket.name = '${oci_objectstorage_bucket.backups.name}'",
  ]
}
