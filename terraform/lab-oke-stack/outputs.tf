output "cluster_id" {
  value = oci_containerengine_cluster.lab_cluster.id
}

output "kubernetes_version" {
  value = local.kubernetes_version
}

output "cluster_public_endpoint" {
  value = oci_containerengine_cluster.lab_cluster.endpoints[0].public_endpoint
}

# Needed by lab-oke-gpu-stack (so GPU nodes join the same NSG and can register)
# and lab-capstone-vllm-stack (LB -> NodePort rules).
output "workers_nsg_id" {
  value = oci_core_network_security_group.workers.id
}
