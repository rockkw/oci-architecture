output "instance_id" {
  value = oci_core_instance.mymagnet.id
}

output "public_ip" {
  value = oci_core_public_ip.mymagnet.ip_address
}

output "backup_bucket_name" {
  value = oci_objectstorage_bucket.backups.name
}
