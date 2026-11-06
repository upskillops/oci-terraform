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

output "public_lb_subnet_id" {
  description = "Use in the Service annotation service.beta.kubernetes.io/oci-load-balancer-subnet1."
  value       = module.network.public_lb_subnet_id
}

output "public_lb_nsg_id" {
  description = "Use in the Service annotation oci.oraclecloud.com/oci-network-security-groups."
  value       = try(module.security.nsg_ids["lb_public"], null)
}

output "reserved_public_ips" {
  description = "Reserved public IPs by name (use as spec.loadBalancerIP)."
  value       = { for k, v in oci_core_public_ip.reserved : k => v.ip_address }
}

output "gitlab_s3_endpoint" {
  value = length(var.gitlab_buckets) > 0 ? "https://${module.storage.namespace}.compat.objectstorage.${var.region}.oraclecloud.com" : null
}

output "gitlab_s3_access_key" {
  value = try(module.gitlab_s3[0].access_key, null)
}

output "gitlab_s3_secret_key" {
  value     = try(module.gitlab_s3[0].secret_key, null)
  sensitive = true
}

output "container_repositories" {
  description = "OCIR image paths (docker login bom.ocir.io -u '<namespace>/<username>' with an OCI auth token)."
  value       = { for k, v in oci_artifacts_container_repository.this : k => "bom.ocir.io/${v.namespace}/${v.display_name}" }
}

output "kafka_bootstrap_servers" {
  value = try(module.kafka[0].bootstrap_servers, null)
}

output "redis" {
  description = "Cluster mode: use cluster_nodes as seeds. Sentinel mode: master name + sentinels."
  value = try({
    mode          = module.redis[0].mode
    cluster_nodes = module.redis[0].cluster_nodes
    primary       = module.redis[0].primary
    sentinels     = module.redis[0].sentinels
    master_name   = module.redis[0].master_name
  }, null)
}

output "redis_password" {
  value     = try(module.redis[0].password, null)
  sensitive = true
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
