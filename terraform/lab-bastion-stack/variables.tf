variable "compartment_ocid" { type = string }
variable "tenancy_ocid" { type = string }
variable "vcn_id" { type = string }
variable "public_subnet_id" { type = string }
variable "private_subnet_id" { type = string }
variable "ssh_public_key" { type = string }
variable "region" {
  type    = string
  default = "us-phoenix-1"
}
