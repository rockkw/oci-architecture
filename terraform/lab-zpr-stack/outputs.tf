output "vm_01_public_ip" {
  value = oci_core_instance.vm_01.public_ip
}

output "vm_02_public_ip" {
  value = oci_core_instance.vm_02.public_ip
}

output "vm_01_private_ip" {
  value = oci_core_instance.vm_01.private_ip
}

output "zpr_policy_id" {
  value = oci_zpr_zpr_policy.ssh_lockdown.id
}
