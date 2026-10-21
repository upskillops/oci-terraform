# Terraform state for the "prod" environment: native OCI Object Storage backend.
bucket    = "tfstate-oke-prod"
namespace = "REPLACE"         # Object Storage namespace (oci os ns get)
key       = "oke-private/prod/terraform.tfstate"
region    = "ap-mumbai-1"

# Credentials come from ~/.oci/config ([DEFAULT] profile). Optional:
# config_file_profile = "DEFAULT"
# auth                = "APIKey"   # or "SecurityToken" / "InstancePrincipal"
