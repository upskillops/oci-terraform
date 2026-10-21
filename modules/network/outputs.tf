output "vcn_id" {
  value = oci_core_vcn.this.id
}

output "subnet_ids" {
  value = { for k, v in oci_core_subnet.this : k => v.id }
}

output "oci_services_cidr" {
  value = local.oci_services.cidr_block
}
