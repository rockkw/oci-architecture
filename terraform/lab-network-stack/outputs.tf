output "vcn_id" {
  value = oci_core_vcn.lab_vcn.id
}

output "subnet_id" {
  value = oci_core_subnet.lab_subnet.id
}
