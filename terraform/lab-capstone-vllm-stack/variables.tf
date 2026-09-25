variable "compartment_ocid" { type = string }
# lab-oke-stack's VCN, which is also lab-mymagnet-stack's VCN (lab-vcn, us-phoenix-1).
variable "vcn_id" { type = string }
# lab-private-network-stack's 10.0.2.0/24 subnet. It holds the OKE workers, the
# MyMagnet instances, and (Phase 2/3) the ADB private endpoint and the Function.
# The internal LB is placed here too.
variable "private_subnet_id" { type = string }
# lab-oke-stack's `workers_nsg_id` output (lab-oke-workers-nsg).
variable "workers_nsg_id" { type = string }

variable "region" {
  type    = string
  default = "us-phoenix-1"
}

variable "client_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

# Plain HTTP for now. See LABS.md "HTTPS later" for the TLS option.
variable "listener_port" {
  type    = number
  default = 80
}

variable "namespace" {
  type    = string
  default = "vllm"
}

# Matches the initial_node_labels entry in lab-oke-cpu-inference-pool-stack.
variable "node_workload_label" {
  type    = string
  default = "llm"
}

# llama.cpp's official CPU server image. The tag is an immutable build number
# (b11176, commit f805c57), not the moving `server` tag. It's a multi-arch index
# (amd64, arm64, s390x), so the A1 node pulls the arm64 build, which includes
# the Neoverse-N1 CPU backend. Checked against the ghcr.io registry API on
# 2026-09-25 (index digest sha256:6257697a7f5d034b8fb499ddb07af3e250506352f94102054252a23f3b85e0af).
variable "llama_server_image" {
  type    = string
  default = "ghcr.io/ggml-org/llama.cpp:server-b11176"
}

# Qwen's official GGUF repo. Apache-2.0 and not gated (checked with the Hugging
# Face API), so no token is needed. ~1.5B params; Q4_K_M is 1,117,320,736 bytes.
variable "model_repo" {
  type    = string
  default = "Qwen/Qwen2.5-1.5B-Instruct-GGUF"
}

variable "model_file" {
  type    = string
  default = "qwen2.5-1.5b-instruct-q4_k_m.gguf"
}

# Hugging Face commit SHA, so a re-download gets the same file.
variable "model_revision" {
  type    = string
  default = "91cad51170dc346986eccefdc2dd33a9da36ead9"
}

# The file's LFS sha256 from the Hugging Face API. The init container refuses
# a download that doesn't match.
variable "model_sha256" {
  type    = string
  default = "6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e"
}

# The model id clients send ("model" in the request) and /v1/models returns
# (llama-server's --alias). lab-capstone-enrich-stack's llm_model uses it.
variable "served_model_name" {
  type    = string
  default = "qwen2.5-1.5b-instruct"
}

# llama-server's --ctx-size. The name is kept from the vLLM version.
variable "max_model_len" {
  type    = number
  default = 4096
}

# llama-server's --threads. Set to the inference node's OCPU count
# (lab-oke-cpu-inference-pool-stack's `ocpus` output); one A1 OCPU is one core.
variable "threads" {
  type    = number
  default = 4
}

variable "cpu_request" {
  type    = string
  default = "3"
}

# Weights ~1.1 GB, KV cache at 4K context ~0.1 GB, plus compute buffers.
variable "memory_request" {
  type    = string
  default = "3Gi"
}

variable "memory_limit" {
  type    = string
  default = "6Gi"
}

# oci-bv block volumes have a 50 GB minimum.
variable "model_cache_size_gb" {
  type    = number
  default = 50
}
