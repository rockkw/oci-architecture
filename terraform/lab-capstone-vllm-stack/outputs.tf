output "lb_nsg_id" {
  value = oci_core_network_security_group.vllm_lb.id
}

# Render to a file and apply by hand:
#   terraform output -raw vllm_manifest > vllm.yaml && kubectl apply -f vllm.yaml
output "vllm_manifest" {
  value = local.vllm_manifest
}
