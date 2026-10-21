output "flow_log_group_id" {
  value = try(oci_logging_log_group.flow[0].id, null)
}

output "alert_topic_id" {
  value = try(oci_ons_notification_topic.alerts[0].id, null)
}
