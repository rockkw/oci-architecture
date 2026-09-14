variable "compartment_ocid" { type = string }
variable "cluster_id" { type = string }
variable "region" {
  type    = string
  default = "us-phoenix-1"
}
# OCIR hostnames use the short region key (e.g. "phx" for us-phoenix-1), not the full
# region name. Keep in sync with `region` above if you change it.
variable "region_key" {
  type    = string
  default = "phx"
}
