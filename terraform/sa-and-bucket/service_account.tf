# Сервисный аккаунт для Terraform.
resource "yandex_iam_service_account" "terraform_sa" {
  folder_id   = var.yc_folder_id
  name        = var.terraform_sa_name
  description = "Service account for Terraform (diploma)"
}

# Роль editor для управления ресурсами.
resource "yandex_resourcemanager_folder_iam_member" "terraform_sa_editor" {
  folder_id = var.yc_folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.terraform_sa.id}"
}

# Роль storage.admin для работы с S3 bucket.
resource "yandex_resourcemanager_folder_iam_member" "terraform_sa_storage" {
  folder_id = var.yc_folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.terraform_sa.id}"
}

# Роль kms.keys.encrypterDecrypter для шифрования бакета.
resource "yandex_resourcemanager_folder_iam_member" "terraform_sa_kms" {
  folder_id = var.yc_folder_id
  role      = "kms.keys.encrypterDecrypter"
  member    = "serviceAccount:${yandex_iam_service_account.terraform_sa.id}"
}

# Статический ключ доступа для сервисного аккаунта (для S3 backend).
resource "yandex_iam_service_account_static_access_key" "terraform_sa_key" {
  service_account_id = yandex_iam_service_account.terraform_sa.id
  description        = "Static access key for S3 backend"
}
