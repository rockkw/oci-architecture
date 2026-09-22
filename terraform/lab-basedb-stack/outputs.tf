output "db_system_id" {
  value = oci_database_db_system.basedb.id
}

output "db_home_id" {
  value = oci_database_db_system.basedb.db_home[0].id
}

output "private_ip" {
  value = oci_database_db_system.basedb.private_ip
}

output "scan_dns_name" {
  value = oci_database_db_system.basedb.scan_dns_name
}
