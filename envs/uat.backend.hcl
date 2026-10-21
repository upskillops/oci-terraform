# Terraform state for the "uat" environment: native OCI Object Storage backend.
bucket    = "in-uat"
namespace = "bmyqoif8kbjq"          # Object Storage namespace (oci os ns get)
key       = "oke-private/uat/terraform.tfstate"
region    = "ap-mumbai-1"

# Credentials come from ~/.oci/config ([DEFAULT] profile). Optional:
config_file_profile = "DEFAULT"
# auth                = "APIKey"   # or "SecurityToken" / "InstancePrincipal"
