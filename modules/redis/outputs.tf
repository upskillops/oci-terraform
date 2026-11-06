output "private_ips" {
  value = local.ips
}

output "mode" {
  value = var.mode
}

output "cluster_nodes" {
  description = "Cluster mode: seed nodes for a Redis Cluster client."
  value       = var.mode == "cluster" ? join(",", local.cluster_nodes) : null
}

output "primary" {
  description = "Sentinel mode: initial primary; after a failover ask Sentinel."
  value       = var.mode == "sentinel" ? "${local.primary_ip}:6379" : null
}

output "sentinels" {
  value = var.mode == "sentinel" ? join(",", [for ip in local.ips : "${ip}:26379"]) : null
}

output "master_name" {
  value = var.mode == "sentinel" ? var.master_name : null
}

output "client_ports" {
  description = "Ports clients need (used for the NSG rules)."
  value       = var.mode == "cluster" ? [6379, 6380] : [6379, 26379]
}

output "password" {
  value     = random_password.redis.result
  sensitive = true
}
