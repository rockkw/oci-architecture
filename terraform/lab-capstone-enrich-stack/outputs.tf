output "input_bucket_name" {
  value = oci_objectstorage_bucket.results.name
}

output "output_bucket_name" {
  value = oci_objectstorage_bucket.enrichment.name
}

output "function_id" {
  value = oci_functions_function.enrich.id
}

# Phase 4: use this as the source NSG on the internal vLLM LB's ingress rule.
output "function_nsg_id" {
  value = oci_core_network_security_group.enrich_func.id
}

output "events_rule_id" {
  value = oci_events_rule.on_result_upload.id
}

output "dynamic_group_id" {
  value = oci_identity_dynamic_group.enrich_func.id
}
