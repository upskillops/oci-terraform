output "nsg_ids" {
  value = local.nsg_ids
}

output "rule_ids" {
  description = "NSG rule IDs, so dependents can wait for the rules without a module-wide depends_on."
  value       = { for k, v in oci_core_network_security_group_security_rule.this : k => v.id }
}
