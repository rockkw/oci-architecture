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

# IAM writes (dynamic groups, policies) must go to the tenancy's home region.
provider "oci" {
  alias  = "home"
  region = "us-ashburn-1"
}

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}

resource "oci_objectstorage_bucket" "lab_bucket" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "lab-bucket"
  access_type    = "NoPublicAccess"
  versioning     = "Enabled"
}

resource "oci_identity_dynamic_group" "instance_writers" {
  provider       = oci.home
  compartment_id = var.tenancy_ocid
  name           = "lab-instance-writers"
  description    = "Instances allowed to write to the lab Object Storage bucket"
  matching_rule  = "instance.id = '${var.instance_id}'"
}

resource "oci_identity_policy" "allow_bucket_access" {
  provider       = oci.home
  compartment_id = var.tenancy_ocid
  name           = "lab-instance-bucket-access"
  description    = "Allow lab instances to manage objects in the lab bucket via instance principal auth"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.instance_writers.name} to manage objects in compartment id ${var.compartment_ocid} where target.bucket.name = '${oci_objectstorage_bucket.lab_bucket.name}'"
  ]
}
