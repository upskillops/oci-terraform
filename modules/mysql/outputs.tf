output "db_system_id" {
  value = oci_mysql_mysql_db_system.this.id
}

output "hostname" {
  value = oci_mysql_mysql_db_system.this.endpoints[0].hostname
}

output "ip_address" {
  value = oci_mysql_mysql_db_system.this.endpoints[0].ip_address
}

output "port" {
  value = oci_mysql_mysql_db_system.this.endpoints[0].port
}

output "heatwave_cluster_id" {
  value = try(oci_mysql_heat_wave_cluster.this[0].id, null)
}
