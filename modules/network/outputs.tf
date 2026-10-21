output "vcn_id" {
  value = oci_core_vcn.this.id
}

output "subnet_ids" {
  value = { for k, v in oci_core_subnet.this : k => v.id }
}

output "oci_services_cidr" {
  value = local.oci_services.cidr_block
}

output "public_route_table_id" {
  value = try(oci_core_route_table.public[0].id, null)
}

output "public_lb_subnet_id" {
  value = try(oci_core_subnet.public_lb[0].id, null)
}
