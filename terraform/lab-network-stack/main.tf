terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}

provider "oci" {
  region = var.region
}

resource "oci_core_vcn" "lab_vcn" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "lab-vcn"
  dns_label      = "labvcn"
}

resource "oci_core_internet_gateway" "lab_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.lab_vcn.id
  display_name   = "lab-igw"
  enabled        = true
}

resource "oci_core_route_table" "lab_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.lab_vcn.id
  display_name   = "lab-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.lab_igw.id
  }
}

resource "oci_core_subnet" "lab_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.lab_vcn.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "lab-subnet"
  dns_label                  = "labsub"
  route_table_id             = oci_core_route_table.lab_rt.id
  prohibit_public_ip_on_vnic = false
}
