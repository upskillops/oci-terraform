resource "oci_mysql_mysql_db_system" "this" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_id
  shape_name          = var.shape_name
  subnet_id           = var.subnet_id
  nsg_ids             = var.nsg_ids

  display_name   = "${var.name_prefix}-mysql"
  description    = "MySQL HeatWave for ${var.name_prefix}"
  hostname_label = "${var.name_prefix}-mysql"
  mysql_version  = var.mysql_version

  admin_username          = var.admin_username
  admin_password          = var.admin_password
  data_storage_size_in_gb = var.data_storage_size_gb
  is_highly_available     = var.is_highly_available
  crash_recovery          = "ENABLED"
  freeform_tags           = var.tags

  backup_policy {
    is_enabled        = true
    retention_in_days = var.backup_retention_days
    window_start_time = var.backup_window_start_time
    freeform_tags     = var.tags

    pitr_policy {
      is_enabled = true
    }
  }

  deletion_policy {
    automatic_backup_retention = var.deletion_protection ? "RETAIN" : "DELETE"
    final_backup               = var.deletion_protection ? "REQUIRE_FINAL_BACKUP" : "SKIP_FINAL_BACKUP"
    is_delete_protected        = var.deletion_protection
  }

  dynamic "maintenance" {
    for_each = var.maintenance_window_start_time != null ? [1] : []
    content {
      window_start_time = var.maintenance_window_start_time
    }
  }

  depends_on = [time_sleep.iam_propagation]

  lifecycle {
    precondition {
      condition     = var.admin_password != null
      error_message = "mysql_admin_password must be set (export TF_VAR_mysql_admin_password=...)."
    }
  }
}

# HeatWave in-memory analytics cluster attached to the DB system.
resource "oci_mysql_heat_wave_cluster" "this" {
  count = var.enable_heatwave ? 1 : 0

  db_system_id         = oci_mysql_mysql_db_system.this.id
  shape_name           = var.heatwave_shape_name
  cluster_size         = var.heatwave_cluster_size
  is_lakehouse_enabled = false
}
