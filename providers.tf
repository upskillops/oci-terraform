# Variables for authentication are declared in variables.tf.
provider "oci" {
  region               = var.region
  auth                 = var.oci_auth
  config_file_profile  = var.oci_config_profile
  tenancy_ocid         = var.tenancy_ocid
  user_ocid            = var.user_ocid
  fingerprint          = var.fingerprint
  private_key_path     = var.private_key_path
  private_key_password = var.private_key_password
}
