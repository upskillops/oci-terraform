output "cluster_id" {
  value = oci_containerengine_cluster.this.id
}

output "private_endpoint" {
  value = oci_containerengine_cluster.this.endpoints[0].private_endpoint
}

output "node_pool_ids" {
  value = { for k, v in oci_containerengine_node_pool.this : k => v.id }
}

output "bastion_id" {
  value = try(oci_bastion_bastion.this[0].id, null)
}
