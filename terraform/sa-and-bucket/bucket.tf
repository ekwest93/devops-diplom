# S3 bucket для хранения tfstate.
resource "yandex_storage_bucket" "tfstate" {
  bucket     = var.backend_bucket_name
  access_key = yandex_iam_service_account_static_access_key.terraform_sa_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.terraform_sa_key.secret_key

  # Запретить анонимный доступ.
  anonymous_access_flags {
    read = false
    list = false
  }
}
