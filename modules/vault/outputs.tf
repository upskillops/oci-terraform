output "vault_id" {
  value = oci_kms_vault.this.id
}

output "key_id" {
  value = oci_kms_key.this.id
}

output "db_secret_id" {
  value = oci_vault_secret.db_admin.id
}

output "db_password" {
  value     = local.db_password
  sensitive = true
}
