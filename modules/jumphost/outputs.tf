output "public_ip" {
  value = oci_core_instance.this.public_ip
}

output "private_ip" {
  value = oci_core_instance.this.private_ip
}

output "subnet_cidr" {
  value = oci_core_subnet.public.cidr_block
}
