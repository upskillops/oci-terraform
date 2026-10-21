locals {
  scope = var.compartment_id == var.tenancy_ocid ? "tenancy" : "compartment id ${var.compartment_id}"
  # Matches only DB systems in this compartment acting as their own resource principal.
  dbsystem_principal = "request.principal.type = 'mysqldbsystem', request.resource.compartment.id = '${var.compartment_id}'"
}

# Mandatory for DB systems with NSGs: the DB system creates its VNIC and joins the NSG itself.
# https://docs.oracle.com/en-us/iaas/mysql-database/doc/mandatory-policies-permissions.html
resource "oci_identity_policy" "dbsystem" {
  compartment_id = var.compartment_id
  name           = "${var.name_prefix}-mysql-dbsystem-network"
  description    = "Allow ${var.name_prefix} MySQL DB systems to manage their VNICs and NSG membership"
  freeform_tags  = var.tags

  statements = [
    "Allow any-user to {VNIC_CREATE, VNIC_UPDATE, VNIC_ASSOCIATE_NETWORK_SECURITY_GROUP, VNIC_DISASSOCIATE_NETWORK_SECURITY_GROUP} in ${local.scope} where all {${local.dbsystem_principal}}",
    "Allow any-user to {NETWORK_SECURITY_GROUP_UPDATE_MEMBERS} in ${local.scope} where all {${local.dbsystem_principal}}",
  ]
}

# IAM policies take a short while to propagate.
resource "time_sleep" "iam_propagation" {
  create_duration = "60s"

  depends_on = [oci_identity_policy.dbsystem]
}
