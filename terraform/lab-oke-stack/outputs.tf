output "cluster_id" {
  value = oci_containerengine_cluster.lab_cluster.id
}

output "kubernetes_version" {
  value = local.kubernetes_version
}

output "cluster_public_endpoint" {
  value = oci_containerengine_cluster.lab_cluster.endpoints[0].public_endpoint
}
