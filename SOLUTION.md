# Дипломный практикум в Yandex.Cloud — решение

**Автор:** Плевако С.В.

**Репозиторий:** https://github.com/ekwest93/devops-diplom

---

## Используемый стек

| Компонент | Выбор |
|---|---|
| Облако | Yandex.Cloud |
| IaC | Terraform (S3 backend) |
| Kubernetes | Yandex Managed Service for Kubernetes (региональный мастер) |
| Worker nodes | Прерываемые ВМ |
| Registry | Yandex Container Registry |
| Мониторинг | Helm `kube-prometheus-stack` |
| CI/CD | GitHub Actions |
| Terraform pipeline | GitHub Actions |
| Ingress | Ingress-контроллер + Ingress (80 порт) |

---

## Структура репозитория
```
devops-diplom/
├── README.md
├── SOLUTION.md
├── terraform/
│  ├── sa-and-bucket/
│  └── infra/
├── app/
├── k8s-manifests/
├── .github/workflows/
└── images/
```
...
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

*Раздел будет заполнен после выполнения этапа.*

---

### 1.4. Создание Managed Kubernetes кластера

*Раздел будет заполнен после выполнения этапа.*

---

### 1.5. Создание Yandex Container Registry

*Раздел будет заполнен после выполнения этапа.*
