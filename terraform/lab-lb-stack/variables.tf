variable "compartment_ocid" { type = string }
variable "tenancy_ocid" { type = string }
variable "subnet_id" { type = string }
variable "nsg_id" { type = string }
variable "ssh_public_key" { type = string }
variable "pool_size" {
  type    = number
  default = 2
}
variable "region" {
  type    = string
  default = "us-phoenix-1"
}
