variable "compartment_ocid" { type = string }
variable "tenancy_ocid" { type = string }
# lab-oke-stack's cluster_id (lab-oke-cluster).
variable "cluster_id" { type = string }
# lab-private-network-stack's 10.0.2.0/24 subnet, same as lab-node-pool.
variable "private_subnet_id" { type = string }
variable "ssh_public_key" { type = string }
# lab-oke-stack's `kubernetes_version` output. The node image is picked to match.
variable "kubernetes_version" { type = string }
# lab-oke-stack's `workers_nsg_id` output. Required: nodes outside this NSG
# hit the "register timeout" described in LABS.md.
variable "workers_nsg_id" { type = string }

# One A1 OCPU is one physical Neoverse-N1 core, so 4 OCPUs = 4 llama.cpp
# threads. Qwen2.5-1.5B Q4_K_M needs about 1.1 GB of weights plus well under
# 1 GB of KV cache at 4K context, so 12 GB leaves room for the node's own
# reservations and for trying a 7B Q4 model (~4.7 GB) later.
# List price: $0.01 per OCPU-hour + $0.0015 per GB-hour. This tenancy's Always
# Free A1 allowance (4 OCPU / 24 GB) is already used, so this pool is billed.
variable "ocpus" {
  type    = number
  default = 4
}
variable "memory_in_gbs" {
  type    = number
  default = 12
}
variable "node_pool_size" {
  type    = number
  default = 1
}
variable "region" {
  type    = string
  default = "us-phoenix-1"
}
