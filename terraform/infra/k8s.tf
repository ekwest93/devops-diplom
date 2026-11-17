# Сервисный аккаунт для K8s кластера.
resource "yandex_iam_service_account" "k8s_sa" {
  folder_id = var.yc_folder_id
  name      = "diploma-k8s-sa"
}

# Роли для сервисного аккаунта K8s.
resource "yandex_resourcemanager_folder_iam_member" "k8s_sa_editor" {
  folder_id = var.yc_folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_sa_registry" {
  folder_id = var.yc_folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_sa.id}"
}

# Managed Kubernetes кластер (зональный мастер).
resource "yandex_kubernetes_cluster" "diploma" {
  name       = var.k8s_cluster_name
  network_id = yandex_vpc_network.diploma.id

  master {
    zonal {
      zone      = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.subnet_a.id
    }

    public_ip = true
  }

  service_account_id      = yandex_iam_service_account.k8s_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_sa.id

  release_channel         = "RAPID"
  network_policy_provider = "CALICO"

  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s_sa_editor,
    yandex_resourcemanager_folder_iam_member.k8s_sa_registry,
  ]
}

# Группа worker-нод (прерываемые ВМ).
resource "yandex_kubernetes_node_group" "diploma_nodes" {
  cluster_id = yandex_kubernetes_cluster.diploma.id
  name       = var.k8s_node_group_name

  instance_template {
    platform_id = "standard-v3"

    resources {
      cores         = 2
      memory        = 4
      core_fraction = 20
    }

    # Минимальный размер диска для ноды K8s — 30 ГБ.
    boot_disk {
      type = "network-hdd"
      size = 30
    }

    scheduling_policy {
      preemptible = true
    }

    network_interface {
      nat = true
      subnet_ids = [
        yandex_vpc_subnet.subnet_a.id,
      ]
    }
  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }

  allocation_policy {
    location {
      zone = "ru-central1-a"
    }
  }
}
