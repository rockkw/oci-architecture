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

data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_nat_gateway" "lab_nat" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "lab-nat-gw"
}

resource "oci_core_service_gateway" "lab_sgw" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "lab-service-gw"

  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }
}

resource "oci_core_route_table" "lab_private_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "lab-private-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_nat_gateway.lab_nat.id
  }

  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.lab_sgw.id
  }
}

resource "oci_core_subnet" "lab_private_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = var.vcn_id
  cidr_block                 = "10.0.2.0/24"
  display_name               = "lab-private-subnet"
  dns_label                  = "labpriv"
  route_table_id             = oci_core_route_table.lab_private_rt.id
  prohibit_public_ip_on_vnic = true
}
