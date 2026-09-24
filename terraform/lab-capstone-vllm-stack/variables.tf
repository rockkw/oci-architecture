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

variable "gpu_shape" {
  type    = string
  default = "VM.GPU.A10.1"
}

# Pinned tag, not `latest`/`nightly`. The cu129 build is used instead of the
# default CUDA 13 build because CUDA 12.x runs on older NVIDIA drivers; check the
# driver on the GPU node with `nvidia-smi` before moving to a CUDA 13 tag.
variable "vllm_image" {
  type    = string
  default = "vllm/vllm-openai:v0.30.0-x86_64-cu129"
}

# Apache-2.0 and not gated, so no Hugging Face token is needed.
# ~7.6B params, ~15.2 GB of bf16 weights: fits one 24 GB A10 with room for KV cache.
variable "model" {
  type    = string
  default = "Qwen/Qwen2.5-7B-Instruct"
}

# Hugging Face commit SHA, so a re-download gets the same weights.
variable "model_revision" {
  type    = string
  default = "a09a35458c702b33eeacc393d103063234e8bc28"
}

variable "served_model_name" {
  type    = string
  default = "qwen2.5-7b-instruct"
}

variable "max_model_len" {
  type    = number
  default = 8192
}

variable "gpu_memory_utilization" {
  type    = number
  default = 0.90
}

# oci-bv block volumes have a 50 GB minimum.
variable "model_cache_size_gb" {
  type    = number
  default = 50
}
