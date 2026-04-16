#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# deploy.sh — deploys the full observability stack
# Usage: bash scripts/deploy.sh
# Requires: config.env filled in, kubectl and helm configured
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG="$ROOT_DIR/config.env"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: config.env not found."
  echo "Run: cp config.env.example config.env  then fill in your values."
  exit 1
fi

source "$CONFIG"

echo ""
echo "══════════════════════════════════════════════════"
echo "  Observability Stack — Deploy"
echo "  App namespace : $APP_NAMESPACE"
echo "  Mon namespace : $MONITORING_NAMESPACE"
echo "══════════════════════════════════════════════════"
echo ""

# ── Step 1: Namespaces ────────────────────────────────────────────────────────
echo "▶ [1/7] Creating namespaces..."
kubectl apply -f "$ROOT_DIR/k8s/namespaces/monitoring-namespace.yaml"
echo "  ✓ monitoring namespace ready"

# ── Step 2: Security (RBAC + NetworkPolicy) ───────────────────────────────────
echo "▶ [2/7] Applying RBAC and NetworkPolicies..."
# Substitute APP_NAMESPACE into RBAC manifest
sed "s/\${APP_NAMESPACE}/$APP_NAMESPACE/g; s/\${MONITORING_NAMESPACE}/$MONITORING_NAMESPACE/g" \
  "$ROOT_DIR/k8s/security/rbac.yaml" | kubectl apply -f -
sed "s/\${APP_NAMESPACE}/$APP_NAMESPACE/g; s/\${MONITORING_NAMESPACE}/$MONITORING_NAMESPACE/g; s/\${METRICS_PORT}/$METRICS_PORT/g" \
  "$ROOT_DIR/k8s/security/network-policies.yaml" | kubectl apply -f -
echo "  ✓ RBAC and NetworkPolicies applied"

# ── Step 3: Prometheus ────────────────────────────────────────────────────────
echo "▶ [3/7] Deploying Prometheus (kube-prometheus-stack)..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update prometheus-community

sed "s/\${PROMETHEUS_RETENTION}/$PROMETHEUS_RETENTION/g; \
     s/\${PROMETHEUS_STORAGE}/$PROMETHEUS_STORAGE/g" \
  "$ROOT_DIR/observability/prometheus/values.yaml" > /tmp/prometheus-values.yaml

helm upgrade --install kube-prom-stack prometheus-community/kube-prometheus-stack \
  --namespace "$MONITORING_NAMESPACE" \
  --values /tmp/prometheus-values.yaml \
  --version "$PROMETHEUS_HELM_VERSION" \
  --wait --timeout 5m
echo "  ✓ Prometheus deployed"

# ── Step 4: ServiceMonitors + Alert rules ─────────────────────────────────────
echo "▶ [4/7] Applying ServiceMonitors and alert rules..."
sed "s/\${APP_NAMESPACE}/$APP_NAMESPACE/g; \
     s/\${APP_LABEL_KEY}/$APP_LABEL_KEY/g; \
     s/\${APP_LABEL_VALUE}/$APP_LABEL_VALUE/g; \
     s/\${MAIN_SERVICE_NAME}/$MAIN_SERVICE_NAME/g; \
     s/\${JOBS_SERVICE_NAME}/$JOBS_SERVICE_NAME/g; \
     s/\${DATA_SERVICE_NAME}/$DATA_SERVICE_NAME/g; \
     s/\${SCRAPE_INTERVAL}/$SCRAPE_INTERVAL/g; \
     s/\${METRICS_PORT}/$METRICS_PORT/g" \
  "$ROOT_DIR/observability/prometheus/service-monitor.yaml" | kubectl apply -f -

sed "s/\${ALERT_ERROR_RATE_THRESHOLD}/$ALERT_ERROR_RATE_THRESHOLD/g; \
     s/\${ALERT_KAFKA_LAG_THRESHOLD}/$ALERT_KAFKA_LAG_THRESHOLD/g; \
     s/\${ALERT_DB_CONNECTIONS_THRESHOLD}/$ALERT_DB_CONNECTIONS_THRESHOLD/g; \
     s/\${ALERT_MEMORY_THRESHOLD}/$ALERT_MEMORY_THRESHOLD/g; \
     s/\${APP_NAMESPACE}/$APP_NAMESPACE/g; \
     s|\${RUNBOOK_BASE_URL}|$RUNBOOK_BASE_URL|g; \
     s/\${MAIN_SERVICE_NAME}/$MAIN_SERVICE_NAME/g" \
  "$ROOT_DIR/observability/prometheus/alerts.yaml" | kubectl apply -f -
echo "  ✓ ServiceMonitors and alerts applied"

# ── Step 5: Grafana ───────────────────────────────────────────────────────────
echo "▶ [5/7] Deploying Grafana..."
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update grafana

sed "s/\${GRAFANA_ADMIN_USER}/$GRAFANA_ADMIN_USER/g; \
     s/\${GRAFANA_ADMIN_PASSWORD}/$GRAFANA_ADMIN_PASSWORD/g; \
     s/\${GRAFANA_FOLDER_NAME}/$GRAFANA_FOLDER_NAME/g; \
     s/\${MONITORING_NAMESPACE}/$MONITORING_NAMESPACE/g" \
  "$ROOT_DIR/observability/grafana/values.yaml" > /tmp/grafana-values.yaml

helm upgrade --install grafana grafana/grafana \
  --namespace "$MONITORING_NAMESPACE" \
  --values /tmp/grafana-values.yaml \
  --wait --timeout 3m

kubectl apply -f "$ROOT_DIR/observability/grafana/grafana-dashboards-configmap.yaml"
echo "  ✓ Grafana deployed"

# ── Step 6: Jaeger ────────────────────────────────────────────────────────────
echo "▶ [6/7] Deploying Jaeger..."
sed "s/\${JAEGER_IMAGE_VERSION}/$JAEGER_IMAGE_VERSION/g; \
     s/\${JAEGER_MAX_TRACES}/$JAEGER_MAX_TRACES/g" \
  "$ROOT_DIR/observability/jaeger/jaeger-deployment.yaml" | kubectl apply -f -
echo "  ✓ Jaeger deployed"

# ── Step 7: Alertmanager config ───────────────────────────────────────────────
echo "▶ [7/7] Configuring Alertmanager..."
sed "s/\${ALERT_EMAIL_TO}/$ALERT_EMAIL_TO/g; \
     s/\${ALERT_EMAIL_FROM}/$ALERT_EMAIL_FROM/g; \
     s/\${ALERT_SMTP_HOST}/$ALERT_SMTP_HOST/g; \
     s/\${ALERT_SMTP_USER}/$ALERT_SMTP_USER/g; \
     s/\${ALERT_SMTP_PASSWORD}/$ALERT_SMTP_PASSWORD/g; \
     s|\${ALERT_SLACK_WEBHOOK}|$ALERT_SLACK_WEBHOOK|g; \
     s/\${ALERT_SLACK_CHANNEL}/$ALERT_SLACK_CHANNEL/g" \
  "$ROOT_DIR/observability/alertmanager/alertmanager-config.yaml" | kubectl apply -f -
echo "  ✓ Alertmanager configured"

echo ""
echo "══════════════════════════════════════════════════"
echo "  Deploy complete. Run: bash scripts/verify.sh"
echo "══════════════════════════════════════════════════"
