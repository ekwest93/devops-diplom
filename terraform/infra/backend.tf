# Terraform backend на базе S3 bucket в Yandex.Cloud.
terraform {
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket = "devops-diplom-tfstate-eujvbn7"
    region = "ru-central1"
    key    = "infra/terraform.tfstate"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
