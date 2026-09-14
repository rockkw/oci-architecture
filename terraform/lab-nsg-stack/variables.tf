variable "compartment_ocid" { type = string }
variable "tenancy_ocid"     { type = string }
variable "vcn_id"           { type = string }
variable "subnet_id"        { type = string }
variable "region" {
  type    = string
  default = "us-phoenix-1"
}
variable "ssh_public_key" { type = string }
