output "load_balancer_ip" {
  value = oci_load_balancer_load_balancer.lab_lb.ip_address_details[0].ip_address
}
