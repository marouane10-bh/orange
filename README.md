# Story 2.3 — Observability Stack

> **Epic 2 — Target Architecture & Platform Foundation**  
> PoC Migration: BPMN Engine on Kubernetes  
> Covers: Prometheus · Grafana · OpenTelemetry · Jaeger · Alertmanager

---

## What this repository is

This repository contains the **complete, ready-to-use observability stack** for monitoring a Quarkus/Kogito (or any Quarkus-based) application deployed on Kubernetes.

It is structured as a **template**: every value that is project-specific (namespace names, service names, alert thresholds, email addresses) is either extracted into [`config.env`](#configuration) or clearly marked with a `# CHANGE ME` comment so you can adapt it in minutes.

---

## Table of contents

- [Architecture overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Quick start](#quick-start)
- [File structure](#file-structure)
- [Task breakdown](#task-breakdown)
  - [T-01 — Micrometer in Quarkus](#t-01--micrometer-in-quarkus)
  - [T-02 — Prometheus](#t-02--prometheus)
  - [T-03 — Grafana](#t-03--grafana)
  - [T-04 — OpenTelemetry](#t-04--opentelemetry)
  - [T-05 — Jaeger](#t-05--jaeger)
  - [T-06 — Alerts](#t-06--alerts)
  - [T-07 — Runbooks](#t-07--runbooks)
- [Verification checklist](#verification-checklist)
- [Cross-team dependencies](#cross-team-dependencies)
- [Glossary](#glossary)

---

## Architecture overview

```
┌─────────────────────────────────────────────────────────────────┐
│  namespace: monitoring                                           │
│                                                                  │
│  ┌─────────────┐    scrapes     ┌──────────────────────────┐    │
│  │  Prometheus │ ◄───────────── │  ServiceMonitors         │    │
│  │  :9090      │                │  (one per app service)   │    │
│  └──────┬──────┘                └──────────────────────────┘    │
│         │ datasource                       ▲                    │
│         ▼                                  │ port 9000          │
│  ┌─────────────┐    receives  ┌────────────┴─────────────────┐  │
│  │  Grafana    │              │  namespace: your-app-ns      │  │
│  │  :3000      │    traces    │                              │  │
│  └─────────────┘ ◄────────── │  [your-service]  :8080 app  │  │
│                               │                  :9000 mgmt │  │
│  ┌─────────────┐              │  [jobs-service]             │  │
│  │  Jaeger     │ ◄────────── │  [data-index]               │  │
│  │  :16686     │  OTLP:4317  └──────────────────────────────┘  │
│  └─────────────┘                                                 │
│                                                                  │
│  ┌─────────────────┐  fires alerts                              │
│  │  Alertmanager   │ ──────────────► Email / Slack / PagerDuty  │
│  │  :9093          │                                            │
│  └─────────────────┘                                            │
└─────────────────────────────────────────────────────────────────┘
```

**The four pillars:**

| Pillar | Tool | Answers |
|--------|------|---------|
| Metrics | Prometheus + Micrometer | How many? How fast? How much memory? |
| Dashboards | Grafana | Is the platform healthy right now? |
| Tracing | OpenTelemetry + Jaeger | Why did this request take 8 seconds? |
| Alerting | Alertmanager | Who gets paged when something breaks? |

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| `kubectl` | ≥ 1.26 | Apply Kubernetes manifests |
| `helm` | ≥ 3.12 | Install Prometheus stack and Grafana |
| `mvn` | ≥ 3.9 | Build Quarkus services |
| Java | 17 or 21 | Quarkus runtime |
| Kubernetes cluster | ≥ 1.26 | Target platform (minikube, k3s, or cloud) |

---

## Configuration

All project-specific values live in **one place**: `config.env`.  
Copy the example file and fill in your values before running any command.

```bash
cp config.env.example config.env
# Edit config.env with your values
```

See [`config.env.example`](config.env.example) for the full list of variables and their descriptions.

The `scripts/apply.sh` script reads `config.env` and substitutes values into the manifests before applying them.

---

## Quick start

```bash
# 1. Clone and configure
git clone https://github.com/your-org/story-2.3-observability.git
cd story-2.3-observability
cp config.env.example config.env
# Edit config.env

# 2. Create namespaces
kubectl apply -f k8s/namespaces/

# 3. Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 4. Deploy the full stack
bash scripts/deploy.sh

# 5. Verify everything is running
bash scripts/verify.sh
```

---

## File structure

```
story-2.3-observability/
│
├── README.md                          ← you are here
├── config.env.example                 ← COPY THIS and fill in your values
├── .gitignore
│
├── scripts/
│   ├── deploy.sh                      ← deploys the full observability stack
│   └── verify.sh                      ← checks all components are running
│
├── k8s/
│   ├── namespaces/
│   │   └── monitoring-namespace.yaml  ← creates the monitoring namespace
│   └── security/
│       ├── rbac.yaml                  ← Prometheus cross-namespace read access
│       └── network-policies.yaml      ← allow port 9000 from monitoring ns
│
├── observability/
│   ├── prometheus/
│   │   ├── values.yaml                ← Helm config for kube-prometheus-stack
│   │   ├── service-monitor.yaml       ← tells Prometheus what to scrape
│   │   └── alerts.yaml                ← PrometheusRule: all alert definitions
│   │
│   ├── grafana/
│   │   ├── values.yaml                ← Helm config for Grafana
│   │   ├── grafana-dashboards-configmap.yaml
│   │   └── dashboards/
│   │       ├── platform-overview.json ← JVM, CPU, HTTP dashboard
│   │       └── app-processes.json     ← business process dashboard
│   │
│   ├── jaeger/
│   │   └── jaeger-deployment.yaml     ← Jaeger all-in-one for PoC
│   │
│   └── alertmanager/
│       └── alertmanager-config.yaml   ← routing: email + Slack
│
├── quarkus-service/                   ← example Quarkus service instrumentation
│   ├── pom.xml                        ← micrometer + opentelemetry dependencies
│   └── src/main/
│       ├── java/com/yourorg/poc/
│       │   ├── metrics/
│       │   │   └── ProcessMetrics.java     ← custom business counters
│       │   └── service/
│       │       └── ExampleService.java     ← manual OTel span example
│       └── resources/
│           └── application.properties     ← micrometer + otel config
│
└── runbooks/
    ├── HighErrorRate.md
    ├── KafkaConsumerLag.md
    ├── DatabaseDown.md
    └── PodCrashLooping.md
```

---

## Task breakdown

### T-01 — Micrometer in Quarkus

**Goal:** expose metrics from every Quarkus service at `/q/metrics`.

**Files to modify in your services:**
- `pom.xml` → add dependencies (see `quarkus-service/pom.xml`)
- `application.properties` → enable Micrometer on port 9000 (see `quarkus-service/src/main/resources/application.properties`)
- Create `ProcessMetrics.java` (or rename to match your process type)

**Verify:**
```bash
curl http://localhost:9000/q/metrics | grep YOUR_APP_NAME
curl http://localhost:9000/q/health/ready
```

---

### T-02 — Prometheus

**Goal:** deploy Prometheus and point it at your services.

**Files:**
- `observability/prometheus/values.yaml` → Helm configuration
- `observability/prometheus/service-monitor.yaml` → what to scrape

**Key things to change in `service-monitor.yaml`:**
```yaml
# CHANGE ME: your app namespace
namespaceSelector:
  matchNames:
    - your-app-namespace   # ← set in config.env as APP_NAMESPACE

# CHANGE ME: label that your K8s Services have
selector:
  matchLabels:
    app.kubernetes.io/part-of: your-project-name   # ← set in config.env
```

**Deploy:**
```bash
helm install kube-prom-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values observability/prometheus/values.yaml \
  --version 58.3.1
kubectl apply -f observability/prometheus/service-monitor.yaml
```

**Verify:**
```bash
kubectl port-forward -n monitoring svc/kube-prom-stack-prometheus 9090:9090
# Open http://localhost:9090 > Status > Targets → all services: UP
```

---

### T-03 — Grafana

**Goal:** visualize metrics with pre-built dashboards.

**Files:**
- `observability/grafana/values.yaml` → Helm config, datasources
- `observability/grafana/dashboards/platform-overview.json` → JVM/infra dashboard
- `observability/grafana/dashboards/app-processes.json` → business dashboard
- `observability/grafana/grafana-dashboards-configmap.yaml` → packages dashboards for K8s

**Deploy:**
```bash
helm install grafana grafana/grafana \
  --namespace monitoring \
  --values observability/grafana/values.yaml
kubectl apply -f observability/grafana/grafana-dashboards-configmap.yaml
```

**Verify:**
```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
# Open http://localhost:3000 → login with GRAFANA_ADMIN_PASSWORD from config.env
```

---

### T-04 — OpenTelemetry

**Goal:** trace requests across all microservices.

**Files to modify in your services:**
- `pom.xml` → add `quarkus-opentelemetry` dependency
- `application.properties` → set OTLP endpoint to Jaeger

**Key setting:**
```properties
# Points to Jaeger (deployed in T-05)
quarkus.otel.exporter.otlp.traces.endpoint=http://jaeger-collector.monitoring.svc:4317
```

**Verify:**
```bash
kubectl logs -n your-app-namespace -l app=your-service --tail=50 | grep trace_id
```

---

### T-05 — Jaeger

**Goal:** receive and display distributed traces.

**File:** `observability/jaeger/jaeger-deployment.yaml`

**Deploy:**
```bash
kubectl apply -f observability/jaeger/jaeger-deployment.yaml
```

**Verify:**
```bash
kubectl port-forward -n monitoring svc/jaeger-collector 16686:16686
# Open http://localhost:16686 → search for your service name
```

---

### T-06 — Alerts

**Goal:** automated notifications when something breaks.

**Files:**
- `observability/prometheus/alerts.yaml` → alert rules (PromQL thresholds)
- `observability/alertmanager/alertmanager-config.yaml` → email + Slack routing

**Deploy:**
```bash
kubectl apply -f observability/prometheus/alerts.yaml
kubectl apply -f observability/alertmanager/alertmanager-config.yaml
```

**Verify:**
```bash
kubectl port-forward -n monitoring svc/kube-prom-stack-alertmanager 9093:9093
# Open http://localhost:9093
# In Prometheus UI > Alerts → state: inactive = rules loaded, no issue
```

---

### T-07 — Runbooks

**Goal:** step-by-step response guides for every alert.

Each file in `runbooks/` corresponds to one alert rule. When an alert fires, the `runbook:` annotation in `alerts.yaml` links directly to the relevant file.

Update the GitHub URL in `alerts.yaml` to point to your repository:
```yaml
annotations:
  runbook: "https://github.com/YOUR-ORG/YOUR-REPO/blob/main/runbooks/HighErrorRate.md"
```

---

## Verification checklist

Run after full deployment:

```bash
bash scripts/verify.sh
```

Or check manually:

- [ ] `kubectl get pods -n monitoring` → all pods `Running`
- [ ] `kubectl get servicemonitor -n monitoring` → all monitors listed
- [ ] Prometheus UI > Status > Targets → all services `UP`
- [ ] Grafana → both dashboards visible in folder
- [ ] Jaeger → traces appear after triggering a request
- [ ] Prometheus UI > Alerts → all rules listed, state `inactive`
- [ ] Send a test alert: `curl -X POST http://localhost:9093/api/v2/alerts`

---

## Cross-team dependencies

| What you need | Who provides it | Action |
|---------------|-----------------|--------|
| RBAC: Prometheus can read pods/services in app namespace | Story 2.2 (Security) | They must apply `k8s/security/rbac.yaml` |
| NetworkPolicy: allow port 9000 from `monitoring` to app namespace | Story 2.2 (Security) | They must apply `k8s/security/network-policies.yaml` |
| Kafka JMX Prometheus exporter enabled | Story 2.4 (Middleware) | They must add `metricsConfig` in Strimzi Kafka CRD |
| PostgreSQL metrics exporter sidecar | Story 2.4 (Middleware) | They must set `metrics.enabled=true` in PostgreSQL Helm values |

---

## Glossary

| Term | Definition |
|------|-----------|
| **Prometheus** | Time-series database. Scrapes `/metrics` endpoints at regular intervals. |
| **Grafana** | Visualisation platform. Connects to Prometheus to display dashboards. |
| **Micrometer** | Java instrumentation library. Auto-exposes JVM and HTTP metrics in Quarkus. |
| **OpenTelemetry** | Open standard for distributed tracing. Natively supported by Quarkus. |
| **Jaeger** | Distributed tracing backend and UI. Receives traces from OTel exporters. |
| **ServiceMonitor** | Kubernetes CRD. Tells the Prometheus Operator which pods to scrape. |
| **Alertmanager** | Routes fired alerts to notification channels (email, Slack, PagerDuty). |
| **Span / Trace** | A span = one measured operation. A trace = all spans of one full transaction. |
| **kube-prometheus-stack** | Helm chart deploying Prometheus + Grafana + Alertmanager in one command. |
| **OTLP** | OpenTelemetry Protocol. Standard format for sending traces to a collector. |
| **Consumer lag** | Messages in a Kafka topic not yet processed. High lag = events not being handled. |

---

*Story 2.3 | Epic 2 — Observability Stack Template*
