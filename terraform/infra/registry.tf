resource "yandex_container_registry" "diploma" {
  name      = var.registry_name
  folder_id = var.yc_folder_id
}
