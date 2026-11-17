# ID K8s кластера.
output "k8s_cluster_id" {
  value = yandex_kubernetes_cluster.diploma.id
}

# ID Container Registry.
output "registry_id" {
  value = yandex_container_registry.diploma.id
}

# ID VPC.
output "vpc_id" {
  value = yandex_vpc_network.diploma.id
}

# ID подсетей.
output "subnet_ids" {
  value = [
    yandex_vpc_subnet.subnet_a.id,
    yandex_vpc_subnet.subnet_c.id,
  ]
}
