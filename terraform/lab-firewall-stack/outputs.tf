output "web_lb_public_ip" {
  value = oci_load_balancer_load_balancer.web_lb.ip_address_details[0].ip_address
}

output "web_server_1_private_ip" {
  value = oci_core_instance.web_server_1.private_ip
}

output "web_server_2_private_ip" {
  value = oci_core_instance.web_server_2.private_ip
}
