output "private_subnet_id" {
  value = oci_core_subnet.lab_private_subnet.id
}

output "nat_gateway_id" {
  value = oci_core_nat_gateway.lab_nat.id
}
