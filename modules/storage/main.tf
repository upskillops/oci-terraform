data "oci_objectstorage_namespace" "this" {
  compartment_id = var.compartment_id
}

resource "oci_objectstorage_bucket" "this" {
  for_each = var.buckets

  compartment_id = var.compartment_id
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = "${var.name_prefix}-${each.key}"
  access_type    = "NoPublicAccess"
  storage_tier   = each.value.storage_tier
  versioning     = each.value.versioning
  kms_key_id     = var.kms_key_id
  freeform_tags  = var.tags
}

locals {
  scope = var.compartment_id == var.tenancy_ocid ? "tenancy" : "compartment id ${var.compartment_id}"
}

# Lets pods using the given Kubernetes service account read/write ONLY these buckets (OKE workload identity).
resource "oci_identity_policy" "workload" {
  count = var.workload_service_account != null ? 1 : 0

  compartment_id = var.compartment_id
  name           = "${var.name_prefix}-oke-workload-objectstorage"
  description    = "OKE workload ${var.workload_namespace}/${var.workload_service_account} access to Object Storage buckets"
  freeform_tags  = var.tags

  statements = [
    for b in oci_objectstorage_bucket.this :
    "Allow any-user to manage objects in ${local.scope} where all {request.principal.type = 'workload', request.principal.namespace = '${var.workload_namespace}', request.principal.service_account = '${var.workload_service_account}', request.principal.cluster_id = '${var.cluster_id}', target.bucket.name = '${b.name}'}"
  ]
}
