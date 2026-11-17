# Дипломный практикум в Yandex.Cloud - решение

**Автор:** Плевако С.В.

**Репозиторий:** https://github.com/ekwest93/devops-diplom

---

## Используемый стек

| Компонент | Выбор |
|---|---|
| Облако | Yandex.Cloud |
| IaC | Terraform (S3 backend) |
| Kubernetes | Yandex Managed Service for Kubernetes (зональный мастер) |
| Worker nodes | Прерываемые ВМ |
| Registry | Yandex Container Registry |
| Мониторинг | Helm `kube-prometheus-stack` |
| CI/CD | GitHub Actions |
| Terraform pipeline | GitHub Actions |
| Ingress | Ingress-контроллер + Ingress (80 порт) |

---

## Структура репозитория

```text
devops-diplom/
├── README.md
├── SOLUTION.md
├── terraform/
│   ├── sa-and-bucket/
│   └── infra/
├── app/
├── k8s-manifests/
├── .github/workflows/
└── images/
```

---

## 1. Создание облачной инфраструктуры

Подготовим облачную инфраструктуру с помощью Terraform. Процесс разбит на этапы:

1. Создание сервисного аккаунта.
2. Создание S3-бакета для хранения `.tfstate`.
3. Создание VPC и подсетей.
4. Создание Managed Kubernetes кластера.
5. Создание Yandex Container Registry.

---

### 1.1. Создание сервисного аккаунта

Для управления инфраструктурой из Terraform создан сервисный аккаунт
`diploma-terraform-sa` с ролями:

| Роль | Назначение |
|---|---|
| `editor` | управление ресурсами каталога |
| `storage.admin` | работа с S3 bucket |
| `kms.keys.encrypterDecrypter` | шифрование данных в бакете |

**Результат:**

Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

**Скриншот:**

![Сервисный аккаунт](images/sa-created.png)

---

### 1.2. Создание S3-бакета для Terraform backend

Создан S3 bucket `devops-diplom-tfstate-eujvbn7` для хранения `.tfstate`.
Анонимный доступ запрещён.

**Скриншот:**

![Бакет](images/bucket-created.png)

---

### 1.3. Создание VPC и подсетей

VPC `diploma-vpc` и две подсети в разных зонах доступности:

| Подсеть | Зона | CIDR |
|---|---|---|
| diploma-vpc-subnet-a | ru-central1-a | 10.10.0.0/24 |
| diploma-vpc-subnet-c | ru-central1-d | 10.30.0.0/24 |

Изначально планировались три подсети (a, b, d), но в октябре 2026 в Yandex.Cloud произошла авария, зона `ru-central1-b` была отключена. Поэтому подсеть в зоне b не создавалась, а мастер Kubernetes сделан зональным в `ru-central1-a` (региональный мастер требует ровно три зоны). Это осознанное отклонение от типовой схемы, продиктованное состоянием облака.

---

### 1.4. Создание Managed Kubernetes кластера

Кластер `diploma-k8s` (Managed Service for Kubernetes), мастер зональный в `ru-central1-a`, `public_ip = true`, release channel `RAPID`, network policy provider `CALICO`.

Группа узлов `diploma-k8s-nodes`:

| Параметр | Значение |
|---|---|
| Количество нод | 2 |
| Платформа | standard-v3 |
| vCPU / RAM | 2 / 4 ГБ |
| core_fraction | 20 |
| Диск | network-hdd 30 ГБ |
| Прерываемые | да (preemptible) |
| Публичный IP | да (nat) |
| Зона | ru-central1-a |

Подключение kubectl:

yc managed-kubernetes cluster get-credentials diploma-k8s --external --force --folder-id b1grvjpek3up0eujvbn7
kubectl get nodes

Обе ноды в статусе Ready.

---

### 1.5. Создание Yandex Container Registry

Registry `diploma-registry` (id `crpisa48st8k0ugp6ong`) создан Terraform-ресурсом `yandex_container_registry`. В нём хранятся образы:

- `crpisa48st8k0ugp6ong/diploma-app` — тестовое приложение (теги `v1.0.0`, `v1.0.3`, `latest`, sha-коммиты)
- `crpisa48st8k0ugp6ong/prom/node-exporter` — зеркало node-exporter
- `crpisa48st8k0ugp6ong/prom/prometheus` — зеркало Prometheus

Зеркала понадобились потому, что `quay.io` и `registry.k8s.io` недоступны из РФ, а Docker Hub нестабилен с нод кластера.

---

## 2. Система мониторинга

Установлен kube-prometheus-stack через Helm в namespace monitoring.
Все поды в namespace monitoring в статусе Running.
Финальные values зафиксированы в k8s-manifests/monitoring/values.yaml.

Особенности:
- prometheusOperator.tls.enabled=false и admissionWebhooks.enabled=false, иначе deployment оператора не мог смонтировать секрет.
- node-exporter и Prometheus используют образы из Yandex Container Registry (зеркала), потому что quay.io недоступен из РФ.

---

## 3. Тестовое приложение

Приложение - статическая страница, отдаваемая nginx.

Файлы:
- app/web-app/index.html - HTML-страница
- app/nginx/nginx.conf - конфигурация nginx
- app/Dockerfile - образ на базе nginx:1.27-alpine

Образ залит в Yandex Container Registry: cr.yandex/crpisa48st8k0ugp6ong/diploma-app:v1.0.0

---

## 4. Ingress и доступ на 80 порту
Установлен Ingress-контроллер NGINX из Yandex Cloud Marketplace (образ из cr.yandex, т.к. registry.k8s.io недоступен).

Внешний IP балансировщика: 46.243.211.5.

Маршрутизация:

| Что | Путь | Namespace | Сервис |
|---|---|---|---|
| Приложение | / | app | diploma-app |
| Grafana | /grafana | monitoring | kube-prometheus-grafana |

Grafana настроена на работу с subpath (server.root_url = http://46.243.211.5/grafana/, serve_from_sub_path = true), поэтому открывается по пути /grafana без отдельного домена и без правки /etc/hosts.

Ссылки (порт 80):

- Grafana: http://46.243.211.5/grafana
- Приложение: http://46.243.211.5

Доступ к Grafana: логин admin. Пароль хранится в секрете kube-prometheus-grafana (namespace monitoring) и может быть получен командой:

kubectl get secret -n monitoring kube-prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d

---

## 5. CI/CD на GitHub Actions

В репозитории настроены три пайплайна.

### 5.1. CI - сборка образа при коммите

Файл .github/workflows/ci.yml.
Триггер: push в main при изменениях в app/ или в самом workflow.
Действия: сборка Docker-образа, push в Yandex Container Registry с тегами по sha коммита и latest.

Особенности:
- yc CLI устанавливается внутри runner.
- SA-ключ передаётся через секрет YC_SA_KEY_JSON, JSON вырезается из секрета.
- Сборка только под linux/amd64, provenance: false (иначе cr.yandex отвергает multi-platform manifest).

### 5.2. CD - релиз и деплой при теге

Файл .github/workflows/cd.yml.
Триггер: push тега v*.*.*.
Действия: сборка образа с тегом релиза, push в registry, деплой в Kubernetes через kubectl set image.

Особенности:
- kubeconfig генерируется прямо на runner через yc managed-kubernetes cluster get-credentials.

### 5.3. Terraform pipeline

Файл .github/workflows/terraform.yml.
Триггер: push в main при изменениях в terraform/infra/.
Действия: terraform init (S3 backend), plan, apply.

Секреты репозитория: YC_SA_KEY_JSON, YC_REGISTRY_ID, TF_SA_KEY_JSON, TF_ACCESS_KEY, TF_SECRET_KEY.

---

## 6. Проверка полного цикла

- Коммит в main - CI собирает и пушит образ с тегом sha и latest.
- Пуш тега v1.0.3 - CD собирает образ с тегом v1.0.3 и деплоит его в кластер. Проверено: kubectl get deployment -n app diploma-app показывает образ cr.yandex/crpisa48st8k0ugp6ong/diploma-app:v1.0.3, поды Running.
- Коммит в terraform/infra - Terraform pipeline выполняет apply.

---

## 7. Отклонения от типовой схемы

1. Зональный мастер Kubernetes в ru-central1-a вместо регионального.
   Причина: в октябре 2026 зона ru-central1-b была отключена после аварии в Yandex.Cloud, а региональный мастер требует ровно три зоны. Подсеть в зоне b не создавалась.

2. Образы node-exporter и Prometheus взяты из Yandex Container Registry (зеркала).
   Причина: quay.io недоступен из РФ, registry.k8s.io также недоступен (CDN таймаутит). Docker Hub нестабилен с нод кластера.

3. Ingress-контроллер NGINX взят из Yandex Cloud Marketplace.
   Причина: registry.k8s.io недоступен, образ контроллера из Marketplace лежит в cr.yandex и доступен нодам.

---

## 8. Заключение

В ходе практикума развёрнута облачная инфраструктура в Yandex.Cloud с помощью Terraform (S3 backend в Object Storage, отдельные папки для SA/bucket и основной инфраструктуры). Поднят Managed Kubernetes кластер с прерываемыми worker-нодами. Установлена система мониторинга kube-prometheus-stack (Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics, operator). Настроены три пайплайна GitHub Actions: CI (сборка образа), CD (релиз и деплой по тегу), Terraform (apply по коммиту в main). Grafana и тестовое приложение доступны по HTTP на 80 порту через Ingress.

---
