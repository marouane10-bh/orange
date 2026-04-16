# Runbook: PodCrashLooping / HighJVMMemoryUsage

**Alerts:**
- `PodCrashLooping` — Severity: Critical — Pod repeatedly crashing
- `HighJVMMemoryUsage` — Severity: Warning — JVM heap above 90% (OOMKill risk)

---

## What this means

**PodCrashLooping:** A pod starts, crashes, and Kubernetes restarts it — repeatedly. The application is completely unavailable for that pod. If all replicas are crashing, the service is fully down.

**HighJVMMemoryUsage:** The JVM heap is above 90% of its configured limit. Kubernetes will OOMKill the pod if it exceeds 100%, which causes a CrashLoopBackOff.

## Business impact

- The affected service is partially or fully unavailable
- In-flight process instances on that pod may be lost (depends on persistence)
- If only some pods are crashing, load balancer may still route traffic — errors will be intermittent

---

## Step 1 — Identify the crashing pod

```bash
# List all pods and their restart counts
kubectl get pods -n YOUR_APP_NAMESPACE

# Find pods with high restart counts
kubectl get pods -n YOUR_APP_NAMESPACE \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}' \
  | sort -k2 -rn | head -5
```

---

## Step 2 — Get the last logs before the crash

The most important logs are from BEFORE the pod crashed — not the current startup logs.

```bash
# Get logs from the PREVIOUS container run (before the crash)
kubectl logs -n YOUR_APP_NAMESPACE YOUR_POD_NAME --previous --tail=100

# Get current startup logs (may show why it's failing to start)
kubectl logs -n YOUR_APP_NAMESPACE YOUR_POD_NAME --tail=50
```

Look for:
- `OutOfMemoryError` → memory issue, see Step 4
- `Connection refused` → dependency (DB, Kafka) is down
- `Configuration error` / `IllegalArgumentException` → bad config, see Step 3
- `java.lang.Error` → JVM-level crash

---

## Step 3 — Check for configuration errors

A bad configuration value (wrong URL, missing secret, invalid property) causes immediate crash on startup.

```bash
# Describe the pod to see environment variables and volume mounts
kubectl describe pod -n YOUR_APP_NAMESPACE YOUR_POD_NAME | grep -A 30 "Environment:"

# Check if referenced secrets exist
kubectl get secret -n YOUR_APP_NAMESPACE

# Check ConfigMaps
kubectl get configmap -n YOUR_APP_NAMESPACE
```

---

## Step 4 — OOMKill diagnosis

If the logs show `OutOfMemoryError` or `kubectl describe pod` shows `OOMKilled`:

```bash
# Check last termination reason
kubectl describe pod -n YOUR_APP_NAMESPACE YOUR_POD_NAME \
  | grep -A 5 "Last State:"
# Look for: Reason: OOMKilled
```

**Short-term fix** — increase memory limit in the deployment:

```bash
# Edit the deployment
kubectl edit deployment YOUR_MAIN_SERVICE_NAME -n YOUR_APP_NAMESPACE
# Find: resources.limits.memory
# Change: 512Mi → 768Mi (or appropriate value)
```

**Root cause** — open Grafana → **Platform Overview** → **JVM Heap Used** panel.  
Check whether heap was growing continuously (memory leak) or spiked suddenly (large load).

---

## Step 5 — Check Kubernetes events

```bash
# Get events for the crashing pod
kubectl describe pod -n YOUR_APP_NAMESPACE YOUR_POD_NAME | grep -A 20 "Events:"

# Get all recent events in the namespace
kubectl get events -n YOUR_APP_NAMESPACE \
  --sort-by='.lastTimestamp' | tail -20
```

---

## Step 6 — Force a clean restart

If the pod is stuck in a restart loop and the root cause is fixed:

```bash
# Delete the pod — Kubernetes will create a new one
kubectl delete pod -n YOUR_APP_NAMESPACE YOUR_POD_NAME

# Watch the new pod start
kubectl get pods -n YOUR_APP_NAMESPACE -w
```

---

## Step 7 — Escalation

If CrashLoopBackOff persists after addressing config and memory:

1. Capture: `kubectl logs --previous`, `kubectl describe pod`, events
2. Check if a recent deployment introduced the regression:
   ```bash
   kubectl rollout history deployment/YOUR_MAIN_SERVICE_NAME -n YOUR_APP_NAMESPACE
   ```
3. Roll back if needed:
   ```bash
   kubectl rollout undo deployment/YOUR_MAIN_SERVICE_NAME -n YOUR_APP_NAMESPACE
   ```
4. Notify the technical lead with: pod name, error from logs, deployment history

---

## Recovery confirmation

- `PodCrashLooping` resolves when the pod stays in `Running` state for 2 minutes
- `HighJVMMemoryUsage` resolves when heap drops below the threshold
- Confirm in Grafana → **Platform Overview** → no red panels
