locals {
  scope = var.compartment_id == var.tenancy_ocid ? "tenancy" : "compartment id ${var.compartment_id}"
}

resource "oci_kms_vault" "this" {
  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-vault"
  vault_type     = var.vault_type
  freeform_tags  = var.tags
}

resource "oci_kms_key" "this" {
  compartment_id      = var.compartment_id
  display_name        = "${var.name_prefix}-key"
  management_endpoint = oci_kms_vault.this.management_endpoint
  protection_mode     = var.key_protection_mode
  freeform_tags       = var.tags

  key_shape {
    algorithm = "AES"
    length    = 32
  }

  is_auto_rotation_enabled = true

  auto_key_rotation_details {
    rotation_interval_in_days = var.key_rotation_days
  }
}

# Let OKE (secrets, boot/block volumes) and Object Storage use the key.
resource "oci_identity_policy" "kms" {
  compartment_id = var.compartment_id
  name           = "${var.name_prefix}-kms-service-access"
  description    = "Allow OCI services to use the ${var.name_prefix} encryption key"
  freeform_tags  = var.tags

  statements = [
    "Allow service blockstorage, objectstorage-${var.region}, oke to use keys in ${local.scope} where target.key.id = '${oci_kms_key.this.id}'"
  ]
}

resource "random_password" "db" {
  count = var.db_password == null ? 1 : 0

  length           = 24
  special          = true
  override_special = "#%^*-_+="
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

locals {
  db_password = coalesce(var.db_password, try(random_password.db[0].result, null))
}

resource "oci_vault_secret" "db_admin" {
  compartment_id = var.compartment_id
  vault_id       = oci_kms_vault.this.id
  key_id         = oci_kms_key.this.id
  secret_name    = "${var.name_prefix}-mysql-admin-password"
  description    = "MySQL HeatWave admin password"
  freeform_tags  = var.tags

  secret_content {
    content_type = "BASE64"
    content      = base64encode(local.db_password)
  }
}
