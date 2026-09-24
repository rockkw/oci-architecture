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

# Capstone Phase 3. Same Object Storage -> Events -> Function shape as
# lab-document-understanding-stack, but the Function calls a self-hosted LLM
# (Phase 4's vLLM on OKE) instead of Document Understanding, and it runs in
# the MyMagnet VCN's private subnet so it can reach that model's internal LB.

# --- Buckets ---

# Where MyMagnet writes its results. object_events_enabled is the switch
# that makes Object Storage emit createobject events at all; it defaults to
# false, and without it the Events rule below never fires.
# (lab-document-understanding-stack doesn't set it, so its rule wouldn't
# fire either.)
resource "oci_objectstorage_bucket" "results" {
  compartment_id        = var.compartment_ocid
  namespace             = data.oci_objectstorage_namespace.ns.namespace
  name                  = var.input_bucket_name
  access_type           = "NoPublicAccess"
  object_events_enabled = true
}

# A separate output bucket (not a prefix in the input bucket) so the
# function's own writes can never re-trigger the rule. Events stay off here.
resource "oci_objectstorage_bucket" "enrichment" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = var.output_bucket_name
  access_type    = "NoPublicAccess"
}

# --- Networking ---

# The subnet (10.0.2.0/24) already routes 0.0.0.0/0 to a NAT gateway and
# Oracle services to a service gateway, and its security list allows all
# egress, so the function can reach Object Storage and OCIR without this.
# The NSG exists so Phase 4's internal-LB NSG can allow ingress from
# *this NSG* as its source. lab-capstone-vllm-stack currently allows the
# whole 10.0.2.0/24 (client_cidr), which already includes this function;
# the NSG is there for tightening that later.
resource "oci_core_network_security_group" "enrich_func" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "capstone-enrich-func-nsg"
}

resource "oci_core_network_security_group_security_rule" "enrich_func_egress_all" {
  network_security_group_id = oci_core_network_security_group.enrich_func.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# --- Function ---

# Private subnet, not lab-func-stack's public one: the vLLM LB is internal,
# so the function's VNIC has to be inside the VCN to reach it.
resource "oci_functions_application" "enrich" {
  compartment_id             = var.compartment_ocid
  display_name               = "capstone-enrich-app"
  subnet_ids                 = [var.subnet_ocid]
  network_security_group_ids = [oci_core_network_security_group.enrich_func.id]
  # Pinned so the image architecture is predictable. On Apple Silicon,
  # build with --platform linux/amd64 (see LABS.md) or the pull fails.
  shape = "GENERIC_X86"
}

resource "oci_functions_function" "enrich" {
  application_id = oci_functions_application.enrich.id
  display_name   = "capstone-enrich-func"
  memory_in_mbs  = 256

  # source_details replaces the deprecated top-level `image` argument that
  # the older labs use; validate warns on `image` with current providers.
  source_details {
    source_type = "CONTAINER_IMAGE"
    image       = var.function_image
  }
  # Longer than the LLM timeout, so a slow model shows up as an llm_error
  # record written by the function rather than a killed invocation with
  # no output at all.
  timeout_in_seconds = var.llm_timeout_seconds + 60

  # Fn exposes each key as an environment variable. Phase 4 changes only
  # llm_endpoint / llm_model here; no image rebuild. The LLM keys are left
  # out entirely while empty (the provider plans "" as null, which would
  # show a diff on every plan); func.py treats a missing LLM_ENDPOINT as
  # "write a deterministic placeholder tag".
  config = merge(
    {
      INPUT_BUCKET        = oci_objectstorage_bucket.results.name
      OUTPUT_BUCKET       = oci_objectstorage_bucket.enrichment.name
      OUTPUT_PREFIX       = var.output_prefix
      LLM_TIMEOUT_SECONDS = tostring(var.llm_timeout_seconds)
      # Phase 2 hook (write to Autonomous DB). Stays "false" until Phase 2
      # exists; see write_to_adb() in func.py.
      ADB_ENABLED = "false"
    },
    var.llm_endpoint == "" ? {} : { LLM_ENDPOINT = var.llm_endpoint },
    var.llm_model == "" ? {} : { LLM_MODEL = var.llm_model },
    var.llm_api_key_secret_ocid == "" ? {} : { LLM_API_KEY_SECRET_OCID = var.llm_api_key_secret_ocid },
  )
}

# --- Events rule ---

# Filtered to the results bucket in the rule itself (the data filter
# matches the event's data.additionalDetails.bucketName), so uploads to
# other buckets in the compartment don't invoke the function at all.
# func.py checks the bucket again as a second guard.
resource "oci_events_rule" "on_result_upload" {
  compartment_id = var.compartment_ocid
  display_name   = "capstone-enrich-upload-rule"
  description    = "Invoke the enrichment function when MyMagnet writes a result object"
  is_enabled     = true

  condition_details {
    event_types = ["com.oraclecloud.objectstorage.createobject"]
    data = jsonencode({
      additionalDetails = {
        bucketName = [oci_objectstorage_bucket.results.name]
      }
    })
  }

  actions {
    action {
      action_type = "FAAS"
      is_enabled  = true
      function_id = oci_functions_function.enrich.id
    }
  }
}

# --- IAM ---

# Resource principal: the function authenticates as itself, matched by its
# OCID. Same pattern as lab-document-understanding-stack.
resource "oci_identity_dynamic_group" "enrich_func" {
  provider       = oci.home
  compartment_id = var.tenancy_ocid
  name           = "capstone-enrich-func-dyn-grp"
  description    = "Matches the capstone enrichment function for resource-principal access"
  matching_rule  = "ALL {resource.type = 'fnfunc', resource.id = '${oci_functions_function.enrich.id}'}"
}

resource "oci_identity_policy" "enrich_func" {
  provider       = oci.home
  compartment_id = var.compartment_ocid
  name           = "capstone-enrich-policy"
  description    = "Enrichment function: read results bucket, write enrichment bucket; Events may invoke it"

  statements = concat(
    [
      # Read only on the input: the function never changes MyMagnet's results.
      "Allow dynamic-group ${oci_identity_dynamic_group.enrich_func.name} to read objects in compartment id ${var.compartment_ocid} where target.bucket.name = '${oci_objectstorage_bucket.results.name}'",
      # manage (not use) on the output: creating a new object needs
      # OBJECT_CREATE, which only the manage verb includes.
      "Allow dynamic-group ${oci_identity_dynamic_group.enrich_func.name} to manage objects in compartment id ${var.compartment_ocid} where target.bucket.name = '${oci_objectstorage_bucket.enrichment.name}'",
      # Without this, the rule matches but the invocation fails with a 403
      # that only shows up in the rule's metrics, not as an error anywhere
      # obvious. No such policy exists in the tenancy yet (checked 2026-09-24).
      "Allow service cloudEvents to use functions-family in compartment id ${var.compartment_ocid}",
    ],
    # Phase 4's vLLM requires a bearer token (--api-key). The function reads
    # it from Vault at runtime, scoped to that one secret.
    var.llm_api_key_secret_ocid == "" ? [] : [
      "Allow dynamic-group ${oci_identity_dynamic_group.enrich_func.name} to read secret-bundles in compartment id ${var.compartment_ocid} where target.secret.id = '${var.llm_api_key_secret_ocid}'",
    ],
    # Lets the MyMagnet instances upload results. Their dynamic group lives
    # in lab-mymagnet-stack; set writer_dynamic_group_name = "" to skip.
    var.writer_dynamic_group_name == "" ? [] : [
      "Allow dynamic-group ${var.writer_dynamic_group_name} to manage objects in compartment id ${var.compartment_ocid} where target.bucket.name = '${oci_objectstorage_bucket.results.name}'",
    ],
  )
}
