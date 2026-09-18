output "instance_1_id" {
  value = oci_core_instance.mymagnet_1.id
}

output "instance_2_id" {
  value = oci_core_instance.mymagnet_2.id
}

# Replaces the old single-instance "public_ip" output — the LB is now the
# only public entry point, fronted by the same Reserved Public IP that used
# to sit directly on the instance's VNIC.
output "load_balancer_public_ip" {
  value = oci_core_public_ip.mymagnet.ip_address
}

output "load_balancer_id" {
  value = oci_load_balancer_load_balancer.mymagnet.id
}

output "backup_bucket_name" {
  value = oci_objectstorage_bucket.backups.name
}

# Useful for chaining into another stack, or for `oci certs-mgmt` CLI
# lookups against the same CA/cert without re-reading this stack's state.
output "certificate_authority_id" {
  value = oci_certificates_management_certificate_authority.mymagnet.id
}

output "certificate_id" {
  value = oci_certificates_management_certificate.mymagnet.id
}
