variable "compartment_ocid" { type = string }
variable "tenancy_ocid" { type = string }
variable "subnet_ocid" { type = string }
variable "function_image" { type = string }
variable "region" {
  type    = string
  default = "us-phoenix-1"
}
# IAM writes (dynamic group, policy) go to the tenancy's home region — same
# reasoning as lab-storage-stack's oci.home provider alias.
variable "home_region" {
  type    = string
  default = "us-ashburn-1"
}
