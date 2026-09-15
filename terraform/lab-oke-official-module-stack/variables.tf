variable "compartment_ocid" { type = string }
variable "tenancy_ocid" { type = string }
variable "ssh_public_key" { type = string }
variable "region" {
  type    = string
  default = "us-phoenix-1"
}
# IAM writes and identity operations go to the tenancy's home region — same
# reasoning as lab-storage-stack's oci.home provider alias.
variable "home_region" {
  type    = string
  default = "us-ashburn-1"
}
