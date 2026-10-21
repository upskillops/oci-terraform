# ---------------- VCN flow logs ----------------
resource "oci_logging_log_group" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-flow-logs"
  freeform_tags  = var.tags
}

resource "oci_logging_log" "flow" {
  for_each = var.enable_flow_logs ? var.subnet_ids : {}

  display_name       = "${var.name_prefix}-flow-${each.key}"
  log_group_id       = oci_logging_log_group.flow[0].id
  log_type           = "SERVICE"
  is_enabled         = true
  retention_duration = var.flow_log_retention_days
  freeform_tags      = var.tags

  configuration {
    compartment_id = var.compartment_id

    source {
      category    = "all"
      resource    = each.value
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
  }
}

# ---------------- Notifications and alarms ----------------
resource "oci_ons_notification_topic" "alerts" {
  count = var.alert_email != null ? 1 : 0

  compartment_id = var.compartment_id
  name           = "${var.name_prefix}-alerts"
  description    = "Alarm notifications for ${var.name_prefix}"
  freeform_tags  = var.tags
}

resource "oci_ons_subscription" "email" {
  count = var.alert_email != null ? 1 : 0

  compartment_id = var.compartment_id
  topic_id       = oci_ons_notification_topic.alerts[0].id
  protocol       = "EMAIL"
  endpoint       = var.alert_email
  freeform_tags  = var.tags
}

locals {
  mysql_alarms = {
    cpu    = { metric = "CpuUtilization", threshold = 85 }
    memory = { metric = "MemoryUtilization", threshold = 90 }
    disk   = { metric = "DbVolumeUtilization", threshold = 85 }
  }
}

resource "oci_monitoring_alarm" "mysql" {
  for_each = var.alert_email != null && var.enable_mysql_alarms ? local.mysql_alarms : {}

  compartment_id        = var.compartment_id
  metric_compartment_id = var.compartment_id
  display_name          = "${var.name_prefix}-mysql-${each.key}-high"
  namespace             = "oci_mysql_database"
  query                 = "${each.value.metric}[5m]{resourceId = \"${var.mysql_db_system_id}\"}.mean() > ${each.value.threshold}"
  severity              = "CRITICAL"
  pending_duration      = "PT5M"
  is_enabled            = true
  destinations          = [oci_ons_notification_topic.alerts[0].id]
  body                  = "MySQL ${each.value.metric} above ${each.value.threshold}% for ${var.name_prefix}"
  freeform_tags         = var.tags
}
