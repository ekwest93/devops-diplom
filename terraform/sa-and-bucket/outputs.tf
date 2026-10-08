# Идентификатор сервисного аккаунта.
output "service_account_id" {
  value       = yandex_iam_service_account.terraform_sa.id
  description = "Terraform service account ID"
}

# Access key для S3 backend.
output "access_key" {
  value       = yandex_iam_service_account_static_access_key.terraform_sa_key.access_key
  description = "Static access key"
  sensitive   = true
}

# Secret key для S3 backend.
output "secret_key" {
  value       = yandex_iam_service_account_static_access_key.terraform_sa_key.secret_key
  description = "Static secret key"
  sensitive   = true
}

# Имя бакета.
output "bucket_name" {
  value       = yandex_storage_bucket.tfstate.bucket
  description = "Terraform state bucket name"
}
