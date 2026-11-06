output "private_ips" {
  value = local.ips
}

output "bootstrap_servers" {
  value = join(",", [for ip in local.ips : "${ip}:9092"])
}

output "cluster_id" {
  value = random_id.cluster.b64_url
}
