mock_provider "oci" {}

variables {
  compartment_id    = "ocid1.compartment.oc1..aaaa"
  name_prefix       = "t"
  tags              = {}
  vcn_id            = "ocid1.vcn.oc1..aaaa"
  oci_services_cidr = "all-bom-services-in-oracle-services-network"
  cp_subnet_cidr    = "10.0.0.0/28"
  lb_allowed_cidrs  = ["10.0.0.0/8"]
}

run "default_rules" {
  command = plan

  assert {
    condition     = length(oci_core_network_security_group.this) == 5
    error_message = "Expected 5 NSGs (cp, workers, pods, lb, db)."
  }

  assert {
    condition     = length(oci_core_network_security_group_security_rule.this) == 30
    error_message = "Unexpected number of NSG rules with default inputs."
  }
}

run "extra_db_cidr_adds_two_rules" {
  command = plan

  variables {
    db_allowed_cidrs = ["192.168.0.0/16"]
  }

  assert {
    condition     = length(oci_core_network_security_group_security_rule.this) == 32
    error_message = "One extra DB CIDR should add one rule per MySQL port (2)."
  }
}
