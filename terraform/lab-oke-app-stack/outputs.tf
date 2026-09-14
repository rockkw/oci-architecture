output "repository_id" {
  value = oci_artifacts_container_repository.lab_app_repo.id
}

output "repository_path" {
  value = "${var.region_key}.ocir.io/${data.oci_objectstorage_namespace.ns.namespace}/${oci_artifacts_container_repository.lab_app_repo.display_name}"
}
