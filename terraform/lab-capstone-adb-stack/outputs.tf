output "autonomous_database_id" {
  value = oci_database_autonomous_database.mymagnet.id
}

output "private_endpoint_ip" {
  value = oci_database_autonomous_database.mymagnet.private_endpoint_ip
}

# e.g. mymagnetadb.adb.us-phoenix-1.oraclecloud.com -- resolves inside the
# VCN only.
output "private_endpoint_host" {
  value = oci_database_autonomous_database.mymagnet.private_endpoint
}

# TLS (walletless) connect descriptors for each service (_high/_medium/
# _low/_tp/_tpurgent). Use the _tp one for the app. Check the port in the
# string is 1522; if it shows 1521, change it -- the NSG opens 1522 only.
output "connection_profiles" {
  value = [
    for p in oci_database_autonomous_database.mymagnet.connection_strings[0].profiles :
    { name = p.display_name, tls = p.tls_authentication, value = p.value }
  ]
}

output "admin_secret_id" {
  value = oci_vault_secret.adb_admin.id
}

output "app_secret_id" {
  value = oci_vault_secret.adb_app.id
}

output "models_bucket" {
  value = oci_objectstorage_bucket.models.name
}
