#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# verify.sh — checks all observability components are healthy
# Usage: bash scripts/verify.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG="$ROOT_DIR/config.env"

source "$CONFIG"

PASS=0; FAIL=0

check() {
  local label="$1"; local cmd="$2"; local expected="$3"
  if eval "$cmd" 2>/dev/null | grep -q "$expected"; then
    echo "  ✓ $label"
    ((PASS++)) || true
  else
    echo "  ✗ $label  (expected: $expected)"
    ((FAIL++)) || true
  fi
}

echo ""
echo "══════════════════════════════════════════════════"
echo "  Observability Stack — Verification"
echo "══════════════════════════════════════════════════"
echo ""

echo "── Pods ─────────────────────────────────────────"
check "Prometheus running" \
  "kubectl get pods -n $MONITORING_NAMESPACE -l app.kubernetes.io/name=prometheus" "Running"
check "Grafana running" \
  "kubectl get pods -n $MONITORING_NAMESPACE -l app.kubernetes.io/name=grafana" "Running"
check "Alertmanager running" \
  "kubectl get pods -n $MONITORING_NAMESPACE -l app.kubernetes.io/name=alertmanager" "Running"
check "Jaeger running" \
  "kubectl get pods -n $MONITORING_NAMESPACE -l app=jaeger" "Running"

echo ""
echo "── ServiceMonitors ──────────────────────────────"
check "Main service monitor exists" \
  "kubectl get servicemonitor -n $MONITORING_NAMESPACE" "$MAIN_SERVICE_NAME"

echo ""
echo "── Alert rules ──────────────────────────────────"
check "PrometheusRule exists" \
  "kubectl get prometheusrule -n $MONITORING_NAMESPACE" "app-alerts"

echo ""
echo "── Dashboards ConfigMap ─────────────────────────"
check "Grafana dashboards ConfigMap exists" \
  "kubectl get configmap -n $MONITORING_NAMESPACE" "app-dashboards"

echo ""
echo "══════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo "══════════════════════════════════════════════════"

echo ""
echo "── Access UIs (port-forward) ────────────────────"
echo "  Prometheus  : kubectl port-forward -n $MONITORING_NAMESPACE svc/kube-prom-stack-prometheus 9090:9090"
echo "  Grafana     : kubectl port-forward -n $MONITORING_NAMESPACE svc/grafana 3000:80"
echo "  Jaeger      : kubectl port-forward -n $MONITORING_NAMESPACE svc/jaeger-collector 16686:16686"
echo "  Alertmanager: kubectl port-forward -n $MONITORING_NAMESPACE svc/kube-prom-stack-alertmanager 9093:9093"
echo ""

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
