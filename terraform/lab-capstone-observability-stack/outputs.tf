output "log_group_id" {
  value = oci_logging_log_group.mymagnet.id
}

output "custom_log_ids" {
  value = { for k, v in oci_logging_log.custom : k => v.id }
}

output "alarm_topic_id" {
  value = oci_ons_notification_topic.alarms.id
}

output "archive_bucket_name" {
  value = var.enable_log_archive ? oci_objectstorage_bucket.log_archive[0].name : null
}
