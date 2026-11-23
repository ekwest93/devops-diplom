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

**Проверка (вывод команд):**

```text
$ yc iam service-account list
+----------------------+-----------------------+--------+---------------------+----------------------+
|          ID          |         NAME          | LABELS |     CREATED AT      | LAST AUTHENTICATED AT|
+----------------------+-----------------------+--------+---------------------+----------------------+
| ajefecgneainr4p6e1uu | diploma-terraform-sa  |        | 2026-10-08 11:16:40 | 2026-11-17 13:10:00  |
| ajeu91db39pluuqe74fn | diploma-k8s-sa        |        | 2026-10-09 06:59:52 | 2026-11-17 13:00:00  |
+----------------------+-----------------------+--------+---------------------+----------------------+

$ yc iam service-account get diploma-terraform-sa
id: ajefecgneainr4p6e1uu
folder_id: b1grvjpek3up0eujvbn7
created_at: "2026-10-08T11:16:40Z"
name: diploma-terraform-sa
description: Service account for Terraform (diploma)
```

<img width="974" height="149" alt="image" src="https://github.com/user-attachments/assets/29fddd00-2090-4223-a8c1-187d1bc9eb4e" />


---

### 1.2. Создание S3-бакета для Terraform backend

Создан S3 bucket `devops-diplom-tfstate-eujvbn7` для хранения `.tfstate`.
Анонимный доступ запрещён.

**Проверка (вывод команды):**

```text
$ yc storage bucket list
+-------------------------------+----------------------+----------+-----------------------+---------------------+
|             NAME              |      FOLDER ID       | MAX SIZE | DEFAULT STORAGE CLASS |     CREATED AT      |
+-------------------------------+----------------------+----------+-----------------------+---------------------+
| devops-diplom-tfstate-eujvbn7 | b1grvjpek3up0eujvbn7 |        0 | STANDARD              | 2026-10-08 11:16:45 |
+-------------------------------+----------------------+----------+-----------------------+---------------------+
```
<img width="974" height="204" alt="image" src="https://github.com/user-attachments/assets/65252fea-edb8-4b9e-bf7e-32b7d4cef960" />


---

### 1.3. Создание VPC и подсетей

VPC `diploma-vpc` (id `enpgu14895i2mvk06njg`) и три подсети в разных зонах доступности:

| Подсеть | Зона | CIDR |
|---|---|---|
| diploma-vpc-subnet-a | ru-central1-a | 10.10.0.0/24 |
| diploma-vpc-subnet-b | ru-central1-b | 10.20.0.0/24 |
| diploma-vpc-subnet-c | ru-central1-d | 10.30.0.0/24 |

**Проверка (вывод команд):**

```text
$ yc vpc network list
+----------------------+-------------+
|          ID          |    NAME     |
+----------------------+-------------+
| enpgu14895i2mvk06njg | diploma-vpc |
+----------------------+-------------+

$ yc vpc subnet list --folder-id b1grvjpek3up0eujvbn7
+----------------------+----------------------+----------------------+----------------+---------------+
|          ID          |         NAME         |      NETWORK ID      |      ZONE      |     RANGE     |
+----------------------+----------------------+----------------------+----------------+---------------+
| e9bcu82u5f4sjs6ju3kg | diploma-vpc-subnet-a | enpgu14895i2mvk06njg | ru-central1-a  | [10.10.0.0/24]|
| e2l6h2pg58da2lio8f9r | diploma-vpc-subnet-b | enpgu14895i2mvk06njg | ru-central1-b  | [10.20.0.0/24]|
| fl8gunj1d952jjlqpr7c | diploma-vpc-subnet-c | enpgu14895i2mvk06njg | ru-central1-d  | [10.30.0.0/24]|
+----------------------+----------------------+----------------------+----------------+---------------+
```

<img width="1552" height="479" alt="image" src="https://github.com/user-attachments/assets/9e9f0678-7a67-4d0e-8de3-fed3e4c65ffc" />

> **Важно (отклонение от задания):**
> Подсеть в зоне ru-central1-b создана, но развернуть региональный мастер не удалось: зона ru-central1-b отключена для новых ресурсов (ошибка API: zone ru-central1-b is disabled. No new resources could be allocated), а запрос квоты на HDD-диски в зонах ru-central1-b и ru-central1-e отклонён. Региональный мастер требует ровно три зоны, поэтому мастер Kubernetes сделан зональным в ru-central1-a, а ноды размещены в зонах a и d.
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
| Зоны | ru-central1-a, ru-central1-d |

Подключение kubectl:

yc managed-kubernetes cluster get-credentials diploma-k8s --external --force --folder-id b1grvjpek3up0eujvbn7

**Проверка (вывод команды):**

```text
$ kubectl get nodes -o wide
NAME                        STATUS   ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP    OS-IMAGE           KERNEL-VERSION
cl18fiep661amtk292a8-ybav   Ready    <none>   72m   v1.35.1   10.30.0.31    153.51.169.66  Ubuntu 22.04.5 LTS  5.15.0-191-generic
cl18fiep661amtk292a8-yzap   Ready    <none>   73m   v1.35.1   10.10.0.23    89.169.141.62  Ubuntu 22.04.5 LTS  5.15.0-191-generic
```
<img width="1835" height="200" alt="image" src="https://github.com/user-attachments/assets/fd2847e2-21f7-4fd9-8b3d-7027a86f854b" />

> **Важно (отклонение от задания):**
> По заданию требуется региональный мастер с нодами в трёх подсетях. Развернуть его не удалось: зона ru-central1-b отключена для новых ресурсов (ошибка API: zone ru-central1-b is disabled. No new resources could be allocated), а запрос квоты на HDD-диски в зонах ru-central1-b и ru-central1-e отклонён поддержкой. Поэтому мастер сделан зональным в ru-central1-a, ноды размещены в зонах a и d. Это ограничение облака, а не конфигурации.

---

### 1.5. Создание Yandex Container Registry

Registry `diploma-registry` (id `crpisa48st8k0ugp6ong`) создан Terraform. В нём лежат образы приложения:

- cr.yandex/crpisa48st8k0ugp6ong/diploma-app - теги v1.0.0, v1.0.1, v1.0.2, v1.0.3, latest.

Также там лежат образы мониторинга (node-exporter, Prometheus, Grafana), потому что они не тянутся напрямую из РФ.

**Проверка (вывод команды):**

```text
$ yc container image list --repository-name crpisa48st8k0ugp6ong/diploma-app
$ yc container image list --repository-name crpisa48st8k0ugp6ong/diploma-app
+----------------------+---------------------+----------------------------------+-------------------------------------------------------------------------+-----------------+
|          ID          |       CREATED       |               NAME               |                                  TAGS                                   | COMPRESSED SIZE |
+----------------------+---------------------+----------------------------------+-------------------------------------------------------------------------+-----------------+
| crp95t75alm0s7pn39lv | 2026-11-17 13:07:43 | crpisa48st8k0ugp6ong/diploma-app | 7dea5952a6013a301bee804912719e1ebca8893f,                               | 20.0 MB         |
|                      |                     |                                  | latest                                                                  |                 |
| crpjmk018hdsaocgor5j | 2026-11-17 11:16:15 | crpisa48st8k0ugp6ong/diploma-app | v1.0.3                                                                  | 20.0 MB         |
| crps3oqhf965nnpf8n9e | 2026-11-17 11:13:23 | crpisa48st8k0ugp6ong/diploma-app | v1.0.2                                                                  | 20.0 MB         |
| crpl185u7v0c1l9to900 | 2026-11-17 11:11:02 | crpisa48st8k0ugp6ong/diploma-app | v1.0.1                                                                  | 20.0 MB         |
| crp7ajpvfvj6j031pklq | 2026-11-17 11:06:13 | crpisa48st8k0ugp6ong/diploma-app | 2a077ec4bb2973045ed95098c577ca273147a2f3                                | 20.0 MB         |
| crpj9vi6rpu2ranon23u | 2026-11-17 11:03:27 | crpisa48st8k0ugp6ong/diploma-app | sha256:b5795c2fee34b02a05fe5a4f7f6895715fb98dd8d653b6f2ff5cd3099bda4564 | 20.0 MB         |
| crprdru1j42d0dgp680h | 2026-11-17 09:36:15 | crpisa48st8k0ugp6ong/diploma-app | v1.0.0                                                                  | 20.0 MB         |
+----------------------+---------------------+----------------------------------+-------------------------------------------------------------------------+-----------------+
```
<img width="1852" height="710" alt="image" src="https://github.com/user-attachments/assets/1bc13d7e-2954-4d20-a76d-3a3be823ebb0" />
<img width="1111" height="465" alt="image" src="https://github.com/user-attachments/assets/0cd66391-87f4-437a-88c1-f95bc00c573e" />

---

## 2. Система мониторинга

Установлен kube-prometheus-stack через Helm в namespace monitoring:

helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f k8s-manifests/monitoring/values.yaml

**Проверка (вывод команды):**

```text
$ kubectl get pods -n monitoring
NAME                                                     READY   STATUS    RESTARTS   AGE
alertmanager-kube-prometheus-kube-prome-alertmanager-0   2/2     Running   0          118s
kube-prometheus-grafana-78f975c6db-x8l6g                 3/3     Running   0          2m5s
kube-prometheus-kube-prome-operator-759d85449c-thlxp     1/1     Running   0          2m5s
kube-prometheus-kube-state-metrics-857775fbc5-bj2qb      1/1     Running   0          2m5s
kube-prometheus-prometheus-node-exporter-dzkxg           1/1     Running   0          2m5s
kube-prometheus-prometheus-node-exporter-rct29           1/1     Running   0          2m5s
prometheus-kube-prometheus-kube-prome-prometheus-0       2/2     Running   0          119s
```
<img width="1313" height="256" alt="image" src="https://github.com/user-attachments/assets/230e0d73-c77e-4f0b-a015-165ee82a8752" />

Все поды в namespace monitoring в статусе Running: Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics, operator.

Образы node-exporter, Prometheus и Grafana взяты из Yandex Container Registry, так как quay.io и registry.k8s.io недоступны из РФ.

---

## 3. Тестовое приложение

Приложение - статическая страница, отдаваемая nginx.

Файлы в репозитории:
- app/web-app/index.html - HTML-страница;
- app/nginx/nginx.conf - конфигурация nginx;
- app/Dockerfile - образ на базе nginx:1.27-alpine.

Сборка и локальная проверка:

cd ~/devops-diplom/app
docker build -t diploma-app:local .
docker run -d --name diploma-app-test -p 8080:80 diploma-app:local
curl -s http://localhost:8080

**Проверка (вывод команды):**

```text
$ curl -s http://localhost:8080 | head -10
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <title>DevOps Diploma App</title>
</head>
<body>
  <h1>DevOps Diploma</h1>
  <p>Плевако С.В.</p>
  <p>Тестовое приложение работает.</p>
```
<img width="1834" height="869" alt="image" src="https://github.com/user-attachments/assets/d52894b6-4ed6-4671-af74-56d2aa717ae4" />

---

## 4. Ingress и доступ на 80 порту
Установлен Ingress-контроллер ingress-nginx (Helm-чарт из репозитория, k8s-manifests/ingress). Образ контроллера взят из Yandex Container Registry, так как registry.k8s.io недоступен из РФ.

```bash
cd k8s-manifests/ingress
helm install ingress-nginx ./ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.admissionWebhooks.enabled=false
```

**Проверка (вывод команды):**

```text
$ kubectl get svc -n ingress-nginx
NAME                       TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)                      AGE
ingress-nginx-controller   LoadBalancer   10.96.232.101   89.169.139.101   80:31988/TCP,443:31485/TCP   22s
```
<img width="1596" height="90" alt="image" src="https://github.com/user-attachments/assets/bb583757-4b40-4d2d-8dfa-325b152048fe" />

Внешний IP балансировщика: 89.169.139.101.

Тестовое приложение развёрнуто манифестами из k8s-manifests/app (Deployment на 2 реплики, Service, Ingress) в namespace app. Grafana вынесена на путь /grafana через ingress (k8s-manifests/monitoring/grafana-ingress.yaml). Grafana работает с subpath: server.root_url = http://89.169.139.101/grafana/, serve_from_sub_path = true, поэтому отдельный домен и правка /etc/hosts не нужны.

```bash
kubectl create namespace app
kubectl apply -f k8s-manifests/app/
kubectl apply -f k8s-manifests/monitoring/grafana-ingress.yaml
```

**Проверка (вывод команды):**

```text
$ kubectl get pods -n app
NAME                           READY   STATUS    RESTARTS   AGE
diploma-app-5c5877c5b4-qmrfx   1/1     Running   0          71s
diploma-app-5c5877c5b4-xfvqt   1/1     Running   0          71s

$ kubectl get ingress -A
NAMESPACE    NAME             CLASS   HOSTS                       ADDRESS          PORTS   AGE
app          diploma-app      nginx   app.89.169.139.101.nip.io   89.169.139.101   80      79s
app          diploma-app-ip   nginx   *                           89.169.139.101   80      80s
monitoring   grafana          nginx   *                           89.169.139.101   80      21s

$ curl -s -o /dev/null -w "%{http_code}\n" http://89.169.139.101/
200
$ curl -s -o /dev/null -w "%{http_code}\n" http://89.169.139.101/grafana/
302
```



Приложение отдаёт код 200, Grafana отвечает редиректом (302) на страницу входа /grafana/login.

Приложение в браузере (http://89.169.139.101/):

<img width="974" height="243" alt="image" src="https://github.com/user-attachments/assets/57461d92-92ec-455e-a018-f5450ff3bae3" />

Grafana в браузере (http://89.169.139.101/grafana/), дашборд с метриками кластера:
<img width="974" height="444" alt="image" src="https://github.com/user-attachments/assets/f7c28d1a-fc0a-400e-8f3f-189606a4aca5" />


Доступ к Grafana: логин admin, пароль DzY4SwBOsxTIGLQV5WJMDjWtdqscswXok22UftZ7 

Ссылки (порт 80):

- Grafana: http://89.169.139.101/grafana/
- Приложение: http://89.169.139.101/

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
 Сервисный аккаунт для CI/CD - diploma-k8s-sa. Роли: container-registry.admin и editor.

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

## 8.1. Развёртывание с нуля

Порядок действий для полного пересоздания стенда (например, после terraform destroy):

1. Применить инфраструктуру (SA, bucket, VPC, K8s, registry):

   cd terraform/sa-and-bucket && terraform init && terraform apply -auto-approve
   cd ../infra && terraform init && terraform apply -auto-approve

2. Подключить kubectl к кластеру:

   yc managed-kubernetes cluster get-credentials diploma-k8s --external --force --folder-id b1grvjpek3up0eujvbn7

3. Установить мониторинг (образы из cr.yandex):

   helm install kube-prometheus prometheus-community/kube-prometheus-stack \
     --namespace monitoring --create-namespace \
     -f k8s-manifests/monitoring/values.yaml \
     -f k8s-manifests/monitoring/grafana-values.yaml

4. Установить Ingress-контроллер:

   cd k8s-manifests/ingress && \
   helm install ingress-nginx ./ingress-nginx --namespace ingress-nginx --create-namespace \
     --set controller.admissionWebhooks.enabled=false

5. Применить манифесты приложения:

   kubectl create namespace app
   kubectl apply -f k8s-manifests/app/
   kubectl apply -f k8s-manifests/monitoring/grafana-ingress.yaml

6. Проверить, что поды Running, и открыть приложение и Grafana по IP балансировщика.

Для terraform destroy и terraform apply ручные действия не требуются: state хранится в S3, все ресурсы описаны в конфигурации.

---
