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

# IAM writes (dynamic group, policy) must go to the tenancy's home region —
# see lab-storage-stack, which hit this as a hard 403 outside the home region.
provider "oci" {
  alias  = "home"
  region = var.home_region
}

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}

# Object-upload trigger, Events -> Function -> Document Understanding,
# reusing the "high-volume ETL" event-driven pattern from
# Note 14 (Object Storage upload -> Events -> Function -> downstream write).

resource "oci_objectstorage_bucket" "input_bucket" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "lab-docs-input"
  access_type    = "NoPublicAccess"
}

resource "oci_objectstorage_bucket" "output_bucket" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "lab-docs-output"
  access_type    = "NoPublicAccess"
}

resource "oci_functions_application" "lab_docs_app" {
  compartment_id = var.compartment_ocid
  display_name   = "lab-docs-app"
  subnet_ids     = [var.subnet_ocid]
}

resource "oci_functions_function" "lab_docs_func" {
  application_id     = oci_functions_application.lab_docs_app.id
  display_name       = "lab-docs-ocr-func"
  image              = var.function_image
  memory_in_mbs      = 256
  timeout_in_seconds = 120
}

# Events rule: object created in the input bucket -> invoke the Function.
# Filtering to just the input bucket happens in the Function's own code
# (checking the event payload's bucketName), since condition_details'
# event_types filter is broader than one specific bucket.
resource "oci_events_rule" "on_document_upload" {
  compartment_id = var.compartment_ocid
  display_name   = "lab-docs-upload-rule"
  is_enabled     = true

  condition_details {
    event_types = ["com.oraclecloud.objectstorage.createobject"]
    data        = jsonencode({})
  }

  actions {
    action {
      action_type = "FAAS"
      is_enabled  = true
      function_id = oci_functions_function.lab_docs_func.id
    }
  }
}

# Dynamic group matching this Function, and the policy granting it both
# Object Storage access (to read the uploaded doc and write results — the
# Function code itself does this) and Document Understanding access to run
# a processor job — following the resource-principal pattern from Note 14
# (get_resource_principals_signer()) rather than embedding credentials.
resource "oci_identity_dynamic_group" "docs_func_dyn_grp" {
  provider       = oci.home
  compartment_id = var.tenancy_ocid
  name           = "lab-docs-func-dyn-grp"
  description    = "Matches the Document Understanding OCR function for resource-principal access"
  matching_rule  = "ALL {resource.type = 'fnfunc', resource.id = '${oci_functions_function.lab_docs_func.id}'}"
}

resource "oci_identity_policy" "docs_func_policy" {
  provider       = oci.home
  compartment_id = var.compartment_ocid
  name           = "lab-docs-func-policy"
  description    = "Allow the OCR function to read/write Object Storage and run Document Understanding jobs"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.docs_func_dyn_grp.name} to manage objects in compartment id ${var.compartment_ocid} where target.bucket.name = '${oci_objectstorage_bucket.input_bucket.name}'",
    "Allow dynamic-group ${oci_identity_dynamic_group.docs_func_dyn_grp.name} to manage objects in compartment id ${var.compartment_ocid} where target.bucket.name = '${oci_objectstorage_bucket.output_bucket.name}'",
    "Allow dynamic-group ${oci_identity_dynamic_group.docs_func_dyn_grp.name} to manage ai-service-document-family in compartment id ${var.compartment_ocid}",
  ]
}
