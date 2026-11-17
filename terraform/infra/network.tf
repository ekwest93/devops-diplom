# VPC для всего проекта.
resource "yandex_vpc_network" "diploma" {
  name = var.vpc_name
}

# Подсеть в зоне ru-central1-a.
resource "yandex_vpc_subnet" "subnet_a" {
  name           = "${var.vpc_name}-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.diploma.id
  v4_cidr_blocks = ["10.10.0.0/24"]
}

# Подсеть в зоне ru-central1-d.
resource "yandex_vpc_subnet" "subnet_c" {
  name           = "${var.vpc_name}-subnet-c"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.diploma.id
  v4_cidr_blocks = ["10.30.0.0/24"]
}
