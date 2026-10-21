output "vcn_id" {
  value = module.network.vcn_id
}

output "subnet_ids" {
  value = module.network.subnet_ids
}

output "nsg_ids" {
  value = module.security.nsg_ids
}

output "cluster_id" {
  value = module.oke.cluster_id
}

output "cluster_private_endpoint" {
  value = module.oke.private_endpoint
}

output "node_pool_ids" {
  value = module.oke.node_pool_ids
}

output "bastion_id" {
  value = module.oke.bastion_id
}

output "jumphost_public_ip" {
  value = try(module.jumphost[0].public_ip, null)
}

output "jumphost_ssh" {
  value = try("ssh opc@${module.jumphost[0].public_ip}", null)
}

output "kubeconfig_command" {
  value = "oci ce cluster create-kubeconfig --cluster-id ${module.oke.cluster_id} --region ${var.region} --token-version 2.0.0 --kube-endpoint PRIVATE_ENDPOINT --file $HOME/.kube/config"
}

output "object_storage_namespace" {
  value = module.storage.namespace
}

output "bucket_names" {
  value = module.storage.bucket_names
}

output "mysql_hostname" {
  value = try(module.mysql[0].hostname, null)
}

output "mysql_ip_address" {
  value = try(module.mysql[0].ip_address, null)
}

output "mysql_port" {
  value = try(module.mysql[0].port, null)
}

output "mysql_heatwave_cluster_id" {
  value = try(module.mysql[0].heatwave_cluster_id, null)
}

output "vault_id" {
  value = try(module.vault[0].vault_id, null)
}

output "kms_key_id" {
  value = local.kms_key_id
}

output "mysql_admin_secret_id" {
  description = "Vault secret holding the MySQL admin password (read it with: oci secrets secret-bundle get --secret-id <id>)."
  value       = try(module.vault[0].db_secret_id, null)
}

output "mysql_admin_password" {
  description = "Generated MySQL admin password (only when neither Vault nor TF_VAR_mysql_admin_password is used)."
  value       = try(random_password.mysql_admin[0].result, null)
  sensitive   = true
}

output "flow_log_group_id" {
  value = module.observability.flow_log_group_id
}
