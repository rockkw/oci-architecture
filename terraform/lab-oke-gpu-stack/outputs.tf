output "gpu_node_pool_id" {
  value = oci_containerengine_node_pool.gpu_node_pool.id
}

output "node_shape" {
  value = oci_containerengine_node_pool.gpu_node_pool.node_shape
}
