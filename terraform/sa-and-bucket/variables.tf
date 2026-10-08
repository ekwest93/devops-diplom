# Идентификатор облака Yandex.Cloud.
variable "yc_cloud_id" {
  type        = string
  description = "Yandex.Cloud cloud ID"
  default     = "b1gtusuaqn60dr8olfid"
}

# Идентификатор каталога Yandex.Cloud.
variable "yc_folder_id" {
  type        = string
  description = "Yandex.Cloud folder ID"
  default     = "b1grvjpek3up0eujvbn7"
}

# Зона доступности по умолчанию.
variable "yc_zone" {
  type        = string
  description = "Yandex.Cloud default zone"
  default     = "ru-central1-a"
}

# Название бакета для Terraform backend.
variable "backend_bucket_name" {
  type        = string
  description = "S3 bucket name for Terraform state"
  default     = "devops-diplom-tfstate-eujvbn7"
}

# Имя сервисного аккаунта Terraform.
variable "terraform_sa_name" {
  type        = string
  description = "Service account name for Terraform"
  default     = "diploma-terraform-sa"
}
