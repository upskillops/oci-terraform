# Dedicated IAM user with an S3 Customer Secret Key, limited to the given buckets.
# Used by S3-compatible clients (GitLab) that cannot use OCI instance or workload principals.

locals {
  scope            = var.compartment_id == var.tenancy_ocid ? "tenancy" : "compartment id ${var.compartment_id}"
  bucket_condition = join(", ", [for b in var.bucket_names : "target.bucket.name = '${b}'"])
}

resource "oci_identity_user" "this" {
  compartment_id = var.tenancy_ocid
  name           = var.name
  email          = var.email
  description    = "S3-compatible access to ${length(var.bucket_names)} buckets"
  freeform_tags  = var.tags
}

resource "oci_identity_group" "this" {
  compartment_id = var.tenancy_ocid
  name           = var.name
  description    = "S3-compatible access to ${length(var.bucket_names)} buckets"
  freeform_tags  = var.tags
}

resource "oci_identity_user_group_membership" "this" {
  user_id  = oci_identity_user.this.id
  group_id = oci_identity_group.this.id
}

resource "oci_identity_policy" "this" {
  compartment_id = var.compartment_id
  name           = var.name
  description    = "Bucket access for ${var.name}"
  freeform_tags  = var.tags

  statements = [
    "Allow group ${oci_identity_group.this.name} to read buckets in ${local.scope} where any {${local.bucket_condition}}",
    "Allow group ${oci_identity_group.this.name} to manage objects in ${local.scope} where any {${local.bucket_condition}}",
  ]
}

# Access key = id, secret key = key. The secret is only returned at creation (kept in Terraform state).
resource "oci_identity_customer_secret_key" "this" {
  user_id      = oci_identity_user.this.id
  display_name = "${var.name}-s3"
}
