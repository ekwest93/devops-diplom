output "k8s_cluster_id" {
  value = yandex_kubernetes_cluster.diploma.id
}

output "registry_id" {
  value = yandex_container_registry.diploma.id
}

output "vpc_id" {
  value = yandex_vpc_network.diploma.id
}

output "subnet_ids" {
  value = [
    yandex_vpc_subnet.subnet_a.id,
    yandex_vpc_subnet.subnet_b.id,
    yandex_vpc_subnet.subnet_c.id,
  ]
}
