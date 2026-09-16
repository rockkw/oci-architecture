output "input_bucket_name" {
  value = oci_objectstorage_bucket.input_bucket.name
}

output "output_bucket_name" {
  value = oci_objectstorage_bucket.output_bucket.name
}

output "function_id" {
  value = oci_functions_function.lab_docs_func.id
}

output "dynamic_group_id" {
  value = oci_identity_dynamic_group.docs_func_dyn_grp.id
}
