variable "compartment_ocid" { type = string }
variable "subnet_ocid"      { type = string }
variable "function_image"   { type = string }
variable "region" {
  type    = string
  default = "us-phoenix-1"
}
