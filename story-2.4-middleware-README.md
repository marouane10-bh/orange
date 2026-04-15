# Kogito Middleware Deployment on Kubernetes — Story 2.4

## Objectives

This story sets up the middleware layer required to support a Kogito-based runtime environment on Kubernetes.

The main objectives are:

- provision the core middleware services required by Kogito
- deploy them in a Kubernetes cluster with clear namespace separation
- provide persistent storage for runtime services
- provide Kafka-based event infrastructure for inter-service communication
- prepare the environment for future business process and workflow integration

---

## Prerequisites

Before starting, make sure the following tools are installed and working:

- Docker Desktop
- Kubernetes enabled locally
- `kubectl`
- `helm`

Validate the Kubernetes environment with:

```powershell
kubectl get nodes
kubectl config current-context
kubectl get ns
kubectl get pods -A
```

Expected result:

- cluster nodes are in `Ready` state
- the current Kubernetes context is correct
- system namespaces are available

---

## Architecture

The middleware deployment is split across three namespaces:

- `data`
- `kafka`
- `business-automation`

### Logical architecture

```text
+------------------------------------------------------------------+
|                     Kubernetes Cluster                           |
+------------------------------------------------------------------+
|                                                                  |
|  Namespace: data                                                 |
|  --------------------------------------------------------------  |
|  PostgreSQL StatefulSet                                          |
|  - postgresql-0                                                  |
|  - postgresql service                                            |
|                                                                  |
|  Databases:                                                      |
|  - kogito                  -> Jobs Service                       |
|  - kogito_data_index       -> Data Index                         |
|                                                                  |
|  Namespace: kafka                                                |
|  --------------------------------------------------------------  |
|  Strimzi Cluster Operator                                        |
|  Kafka Broker / Controller                                       |
|  Entity Operator                                                 |
|                                                                  |
|  Topics:                                                         |
|  - kogito-jobs-events                                            |
|  - kogito-processinstances-events                                |
|                                                                  |
|  Namespace: business-automation                                  |
|  --------------------------------------------------------------  |
|  Kogito Jobs Service                                             |
|  Kogito Data Index                                               |
|                                                                  |
+------------------------------------------------------------------+
```

### Namespace responsibilities

#### `data`
Contains PostgreSQL and persistent storage resources.

#### `kafka`
Contains the Strimzi operator, Kafka broker resources, and Kafka topics.

#### `business-automation`
Contains the Kogito middleware services:

- Jobs Service
- Data Index

---

## Installation Commands

### 1. Create namespaces

```powershell
kubectl create namespace business-automation
kubectl create namespace kafka
kubectl create namespace data
```

### 2. Deploy PostgreSQL

```powershell
kubectl apply -f infra/story-2.4/postgres/postgres-secret.yaml
kubectl apply -f infra/story-2.4/postgres/postgres-service.yaml
kubectl apply -f infra/story-2.4/postgres/postgres-statefulset.yaml
```

### 3. Install Strimzi

```powershell
helm repo add strimzi https://strimzi.io/charts/
helm repo update
helm install strimzi strimzi/strimzi-kafka-operator -n kafka
```

### 4. Deploy Kafka

```powershell
kubectl apply -f infra/story-2.4/kafka/kafka-nodepool.yaml
kubectl apply -f infra/story-2.4/kafka/kafka-cluster.yaml
```

### 5. Create Kafka topics

```powershell
kubectl apply -f infra/story-2.4/kafka/topics/
```

### 6. Deploy Jobs Service

```powershell
kubectl apply -f infra/story-2.4/jobs-service/jobs-service-secret.yaml
kubectl apply -f infra/story-2.4/jobs-service/jobs-service-configmap.yaml
kubectl apply -f infra/story-2.4/jobs-service/jobs-service-deployment.yaml
kubectl apply -f infra/story-2.4/jobs-service/jobs-service-service.yaml
```

### 7. Create dedicated database for Data Index

```powershell
kubectl exec -it postgresql-0 -n data -- psql -U kogito -d postgres
```

Inside PostgreSQL:

```sql
CREATE DATABASE kogito_data_index OWNER kogito;
\l
\q
```

### 8. Deploy Data Index

```powershell
kubectl apply -f infra/story-2.4/data-index/data-index-secret.yaml
kubectl apply -f infra/story-2.4/data-index/data-index-configmap.yaml
kubectl apply -f infra/story-2.4/data-index/data-index-deployment.yaml
kubectl apply -f infra/story-2.4/data-index/data-index-service.yaml
```

### 9. Restart Data Index after configuration changes if needed

```powershell
kubectl rollout restart deployment/kogito-data-index -n business-automation
```

### 10. Verification commands

```powershell
kubectl get pods -n data
kubectl get pods -n kafka
kubectl get pods -n business-automation
kubectl get svc -n business-automation
kubectl logs -n business-automation deployment/kogito-jobs-service
kubectl logs -n business-automation deployment/kogito-data-index
```
