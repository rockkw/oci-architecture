variable "compartment_ocid" { type = string }
variable "tenancy_ocid" { type = string }
variable "cluster_id" { type = string }
variable "private_subnet_id" { type = string }
variable "ssh_public_key" { type = string }
variable "kubernetes_version" { type = string }
# GPU shapes available on OCI (region/tenancy availability and service-limit quota
# vary — most require a limit increase from Oracle before they can be provisioned).
# See: https://docs.oracle.com/en-us/iaas/Content/Compute/References/computeshapes.htm
#
# VM shapes (no RDMA/cluster networking, simplest to use in a node pool):
#   VM.GPU2.1      - 1x NVIDIA P100
#   VM.GPU3.1      - 1x NVIDIA V100
#   VM.GPU3.2      - 2x NVIDIA V100
#   VM.GPU3.4      - 4x NVIDIA V100
#   VM.GPU.A10.1   - 1x NVIDIA A10   (default below)
#   VM.GPU.A10.2   - 2x NVIDIA A10
#
# Bare metal shapes (higher-end; support RDMA cluster networking for multi-node
# training via compute_cluster_id, which this stack does not configure):
#   BM.GPU2.2         - 2x NVIDIA P100
#   BM.GPU3.8         - 8x NVIDIA V100
#   BM.GPU4.8         - 8x NVIDIA A100
#   BM.GPU.A10.4      - 4x NVIDIA A10
#   BM.GPU.A100-v2.8  - 8x NVIDIA A100
#   BM.GPU.L40S.4     - 4x NVIDIA L40S
#   BM.GPU.H100.8     - 8x NVIDIA H100
#   BM.GPU.H200.8     - 8x NVIDIA H200
#   BM.GPU.B200.8     - 8x NVIDIA B200 (Blackwell)
#   BM.GPU.B300.8     - 8x NVIDIA B300 (Blackwell)
#   BM.GPU.GB200.4    - 4x NVIDIA Grace-Blackwell GB200 superchip
#   BM.GPU.GB300.4    - 4x NVIDIA Grace-Blackwell GB300 superchip
#   BM.GPU.MI300X.8   - 8x AMD MI300X
#   BM.GPU.MI355X.8   - 8x AMD MI355X
#   BM.GPU.RTXPRO.8   - 8x NVIDIA RTX PRO 6000 Blackwell
variable "node_shape" {
  type    = string
  default = "VM.GPU.A10.1"
}
variable "node_pool_size" {
  type    = number
  default = 1
}
variable "region" {
  type    = string
  default = "us-phoenix-1"
}
