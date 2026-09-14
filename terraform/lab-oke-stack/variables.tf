variable "compartment_ocid" { type = string }
variable "tenancy_ocid" { type = string }
variable "vcn_id" { type = string }
variable "public_subnet_id" { type = string }
variable "private_subnet_id" { type = string }
variable "ssh_public_key" { type = string }
variable "kubernetes_version" {
  type    = string
  default = null
}
variable "node_pool_size" {
  type    = number
  default = 2
}
variable "region" {
  type    = string
  default = "us-phoenix-1"
}
