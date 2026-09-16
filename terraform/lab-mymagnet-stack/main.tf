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

# NSG mirrors the AWS README's security group guidance exactly:
# 80/443 open publicly (nginx), 22 restricted to var.ssh_allowed_cidr, and
# explicitly NOT 8080 — webserver.py binds to 127.0.0.1 only, nginx is the
# sole public entry point.
resource "oci_core_network_security_group" "mymagnet" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "mymagnet-nsg"
}

resource "oci_core_network_security_group_security_rule" "ingress_http" {
  network_security_group_id = oci_core_network_security_group.mymagnet.id
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

resource "oci_core_network_security_group_security_rule" "ingress_https" {
  network_security_group_id = oci_core_network_security_group.mymagnet.id
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

resource "oci_core_instance" "mymagnet" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "mymagnet-instance"
  shape               = "VM.Standard.A1.Flex"

  # AWS README sizes this at EC2 t4g.small (2 vCPU/2GB burstable ARM) —
  # OCI's closest equivalent shape/size for "single daily scrape job plus a
  # low-traffic dashboard."
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
    # No ephemeral public IP here — the oci_core_public_ip resource below
    # assigns a Reserved public IP to this VNIC's primary private IP
    # instead, so the instance ends up with exactly one public IP, not two.
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

# Reserved Public IP, assigned directly to the instance's primary private
# IP at creation — not ephemeral, so it survives instance stop/start and
# stays stable for the DNS A record the README's TLS/Certbot step needs
# (same "stop/start-stable IP" distinction documented in Note 9).
data "oci_core_vnic_attachments" "mymagnet" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  instance_id         = oci_core_instance.mymagnet.id
}

data "oci_core_private_ips" "mymagnet" {
  vnic_id = data.oci_core_vnic_attachments.mymagnet.vnic_attachments[0].vnic_id
}

resource "oci_core_public_ip" "mymagnet" {
  compartment_id = var.compartment_ocid
  lifetime       = "RESERVED"
  display_name   = "mymagnet-reserved-ip"
  private_ip_id  = data.oci_core_private_ips.mymagnet.private_ips[0].id
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
  description    = "Matches the MyMagnet instance for resource-principal access to its backup bucket"
  matching_rule  = "ALL {resource.type = 'instance', resource.id = '${oci_core_instance.mymagnet.id}'}"
}

resource "oci_identity_policy" "mymagnet_policy" {
  provider       = oci.home
  compartment_id = var.compartment_ocid
  name           = "mymagnet-backup-policy"
  description    = "Allow the MyMagnet instance to read/write its backup bucket via instance principal"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.mymagnet_dyn_grp.name} to manage objects in compartment id ${var.compartment_ocid} where target.bucket.name = '${oci_objectstorage_bucket.backups.name}'",
  ]
}
