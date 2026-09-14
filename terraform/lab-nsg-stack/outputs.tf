output "instance_public_ip" {
  value = oci_core_instance.nsg_test.public_ip
}
