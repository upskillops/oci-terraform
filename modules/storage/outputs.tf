output "namespace" {
  value = data.oci_objectstorage_namespace.this.namespace
}

output "bucket_names" {
  value = { for k, v in oci_objectstorage_bucket.this : k => v.name }
}
