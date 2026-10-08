resource "yandex_vpc_network" "diploma" {
  name = var.vpc_name
}

resource "yandex_vpc_subnet" "subnet_a" {
  name           = "${var.vpc_name}-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.diploma.id
  v4_cidr_blocks = ["10.10.0.0/24"]
}

resource "yandex_vpc_subnet" "subnet_b" {
  name           = "${var.vpc_name}-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.diploma.id
  v4_cidr_blocks = ["10.20.0.0/24"]
}

resource "yandex_vpc_subnet" "subnet_c" {
  name           = "${var.vpc_name}-subnet-c"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.diploma.id
  v4_cidr_blocks = ["10.30.0.0/24"]
}
