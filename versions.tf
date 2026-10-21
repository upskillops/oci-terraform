
terraform {
  required_version = ">= 1.12.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.0.0, < 8.0.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  backend "oci" {
    bucket              = "wibmo-ivs"
    namespace           = "bmyqoif8kbjq"
    region              = "ap-mumbai-1"
    auth                = "APIKey"
    config_file_profile = "DEFAULT"
  }
}

