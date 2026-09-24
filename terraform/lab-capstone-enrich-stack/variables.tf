variable "compartment_ocid" { type = string }
variable "tenancy_ocid" { type = string }

# MyMagnet's VCN (lab-network-stack's vcn_id), for the function's NSG.
variable "vcn_id" { type = string }

# The NAT-routed private subnet, 10.0.2.0/24 (lab-private-network-stack's
# private_subnet_id, the same value as lab-mymagnet-stack's
# instance_subnet_id). It must be inside the VCN so the function can reach
# Phase 4's internal LB.
variable "subnet_ocid" { type = string }

# Full OCIR path of the pushed image, e.g.
# phx.ocir.io/<namespace>/capstone/enrich:0.0.1. The image has to exist
# before apply; see the build/push steps in LABS.md.
variable "function_image" { type = string }

variable "region" {
  type    = string
  default = "us-phoenix-1"
}
# IAM writes (dynamic group, policy) go to the tenancy's home region — same
# reasoning as lab-storage-stack's oci.home provider alias.
variable "home_region" {
  type    = string
  default = "us-ashburn-1"
}

variable "input_bucket_name" {
  type    = string
  default = "mymagnet-results"
}

variable "output_bucket_name" {
  type    = string
  default = "mymagnet-enrichment"
}

variable "output_prefix" {
  type    = string
  default = "enriched/"
}

# Base URL of Phase 4's vLLM server behind the internal LB, e.g.
# "http://10.0.2.50:8000" (func.py appends /v1/chat/completions). Empty
# until Phase 4, and empty means placeholder tags: the pipeline can be
# tested end to end before any GPU exists.
variable "llm_endpoint" {
  type    = string
  default = ""
}

# The name vLLM serves the model under (its --served-model-name).
variable "llm_model" {
  type    = string
  default = ""
}

# Vault secret holding the key vLLM was started with (lab-capstone-vllm-stack
# runs it with --api-key from the vllm-api-key Kubernetes Secret). Store the
# same value in Vault and pass its OCID here. The function reads the secret
# at runtime, and the policy grants read on just this one secret.
variable "llm_api_key_secret_ocid" {
  type    = string
  default = ""
}

# HTTP timeout for the model call. The function timeout is this plus 60s.
# OCI Functions allows at most 300s per invocation, hence the cap.
variable "llm_timeout_seconds" {
  type    = number
  default = 60
  validation {
    condition     = var.llm_timeout_seconds > 0 && var.llm_timeout_seconds <= 240
    error_message = "llm_timeout_seconds must be 1-240 (function timeout = this + 60, max 300)."
  }
}

# Dynamic group allowed to upload into the results bucket. Defaults to
# lab-mymagnet-stack's instance group; "" leaves it out of the policy.
variable "writer_dynamic_group_name" {
  type    = string
  default = "mymagnet-instance-dyn-grp"
}
