output "bastion_id" {
  value = oci_bastion_bastion.lab_bastion.id
}

output "private_instance_private_ip" {
  value = oci_core_instance.private_instance.private_ip
}

output "session_ssh_metadata" {
  value = oci_bastion_session.private_instance_session.ssh_metadata
}
