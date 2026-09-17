variable "compartment_ocid" { type = string }
variable "tenancy_ocid" { type = string }
variable "region" {
  type    = string
  default = "us-phoenix-1"
}
variable "home_region" {
  type        = string
  description = "Tenancy home region — required for ZPR/security-attribute resources, which are CREATE/UPDATE/DELETE-in-home-region-only per the OCI API."
}
variable "ssh_public_key" { type = string }
