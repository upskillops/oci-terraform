# Keeps existing state when moving from the flat layout to modules (no destroy/recreate).
# Safe to keep: blocks whose "from" does not exist in state are ignored.

moved {
  from = oci_core_vcn.this
  to   = module.network.oci_core_vcn.this
}
moved {
  from = oci_core_nat_gateway.this
  to   = module.network.oci_core_nat_gateway.this
}
moved {
  from = oci_core_service_gateway.this
  to   = module.network.oci_core_service_gateway.this
}
moved {
  from = oci_core_route_table.private
  to   = module.network.oci_core_route_table.private
}
moved {
  from = oci_core_route_table.endpoint
  to   = module.network.oci_core_route_table.endpoint
}
moved {
  from = oci_core_security_list.deny_all
  to   = module.network.oci_core_security_list.deny_all
}
moved {
  from = oci_core_subnet.this
  to   = module.network.oci_core_subnet.this
}
moved {
  from = oci_core_network_security_group.this
  to   = module.security.oci_core_network_security_group.this
}
moved {
  from = oci_core_network_security_group_security_rule.this
  to   = module.security.oci_core_network_security_group_security_rule.this
}
moved {
  from = oci_containerengine_cluster.this
  to   = module.oke.oci_containerengine_cluster.this
}
moved {
  from = oci_containerengine_node_pool.this
  to   = module.oke.oci_containerengine_node_pool.this
}
moved {
  from = oci_bastion_bastion.this
  to   = module.oke.oci_bastion_bastion.this
}
