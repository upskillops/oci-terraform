output "access_key" {
  value = oci_identity_customer_secret_key.this.id
}

output "secret_key" {
  value     = oci_identity_customer_secret_key.this.key
  sensitive = true
}
