output "bucket_name" {
  value = oci_objectstorage_bucket.lab_bucket.name
}

output "dynamic_group_id" {
  value = oci_identity_dynamic_group.instance_writers.id
}
