output "node_pool_id" {
  value = oci_containerengine_node_pool.cpu_inference_pool.id
}

output "node_image_id" {
  value = local.node_image_id
}

# Set lab-capstone-vllm-stack's `threads` to this.
output "ocpus" {
  value = var.ocpus
}
