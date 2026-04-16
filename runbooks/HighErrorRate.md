# Runbook: HighErrorRate

**Alert:** `HighErrorRate`  
**Severity:** Critical  
**Threshold:** Error rate > `ALERT_ERROR_RATE_THRESHOLD`% for 3 consecutive minutes

---

## What this means

A significant proportion of process instances are ending in error.  
In a business context, this means customer-facing operations (orders, activations, provisioning) are failing.

## Business impact

- End users cannot complete their operations
- Depending on the process type, this may cause revenue loss or SLA breach
- Downstream systems that depend on completion events will not receive them

---

## Step 1 — Confirm the alert is real

Open the Grafana dashboard → **Application Processes** → **Process Error Rate** panel.  
If the rate is spiking, check whether it correlates with a deployment or external event.

```bash
# Check recent events in the app namespace
kubectl get events -n YOUR_APP_NAMESPACE --sort-by='.lastTimestamp' | tail -20
```

---

## Step 2 — Find which process instances are failing

```bash
# Get recent error logs from the main service
kubectl logs -n YOUR_APP_NAMESPACE \
  -l app=YOUR_MAIN_SERVICE_NAME \
  --tail=100 \
  --since=10m \
  | grep -i error

# If you have multiple pods, check all of them
kubectl logs -n YOUR_APP_NAMESPACE \
  -l app=YOUR_MAIN_SERVICE_NAME \
  --prefix=true \
  --tail=50 \
  | grep -i "exception\|error\|failed"
```

---

## Step 3 — Trace the failing request in Jaeger

1. Open Jaeger UI:
   ```bash
   kubectl port-forward -n monitoring svc/jaeger-collector 16686:16686
   # → http://localhost:16686
   ```
2. Select your service from the dropdown
3. Add tag filter: `error=true`
4. Click on a failing trace to see which span failed and what the error was

The span name tells you which step of the process failed (e.g. `step1-check-eligibility` or `step2-execute-action`).

---

## Step 4 — Check downstream services

The most common causes of process errors are downstream service failures.

```bash
# Check all pods in the app namespace
kubectl get pods -n YOUR_APP_NAMESPACE

# Check the health endpoint of your service
kubectl exec -n YOUR_APP_NAMESPACE deploy/YOUR_MAIN_SERVICE_NAME -- \
  curl -s http://localhost:9000/q/health/ready | python3 -m json.tool

# Check database connectivity
kubectl exec -n YOUR_APP_NAMESPACE deploy/YOUR_MAIN_SERVICE_NAME -- \
  curl -s http://localhost:9000/q/health/live
```

---

## Step 5 — Check for Kafka issues (if event-driven)

A Kafka consumer lag can cause processes to fail if they depend on incoming events.

```bash
# Check Kafka consumer groups
kubectl exec -n YOUR_APP_NAMESPACE \
  deploy/YOUR_MAIN_SERVICE_NAME -- \
  curl -s http://localhost:9000/q/metrics | grep kafka
```

Open Grafana → **Application Processes** → **Kafka Consumer Lag** panel.  
If lag is growing, see [KafkaConsumerLag.md](./KafkaConsumerLag.md).

---

## Step 6 — Escalation

If the error rate does not drop within **15 minutes**:

1. Create a Jira incident ticket with:
   - Screenshot of Grafana error rate panel
   - A trace ID from Jaeger (copy from the UI)
   - Last 50 lines of logs from the failing pod
2. Notify the technical lead

---

## Recovery confirmation

The alert auto-resolves when the error rate drops below the threshold for 5 minutes.  
Confirm in Prometheus UI → Alerts → `HighErrorRate` shows state: `inactive`.
