# Runbook: DatabaseDown / DatabaseConnectionSaturation

**Alerts:**
- `DatabaseDown` — Severity: Critical — Database not responding
- `DatabaseConnectionSaturation` — Severity: Warning — Connection pool near limit

---

## What this means

**DatabaseDown:** PostgreSQL is completely unreachable. All process instances that try to persist state will fail immediately. No new processes can be created.

**DatabaseConnectionSaturation:** The database is reachable but running out of available connections. Application errors will begin intermittently and worsen as load increases.

## Business impact

- All stateful operations fail (process creation, state updates, history)
- Data may be lost if in-flight transactions are interrupted
- The application cannot recover until the database is restored

---

## Step 1 — Check database pod status

```bash
# Check if the PostgreSQL pod is running
kubectl get pods -n YOUR_APP_NAMESPACE | grep postgres

# If pod is not Running, describe it to see why
kubectl describe pod -n YOUR_APP_NAMESPACE YOUR_POSTGRES_POD_NAME

# Check PostgreSQL logs
kubectl logs -n YOUR_APP_NAMESPACE \
  -l app.kubernetes.io/name=postgresql \
  --tail=100
```

---

## Step 2 — Check persistent volume

A common cause of PostgreSQL crashes is a full or failed persistent volume.

```bash
# Check PVC status
kubectl get pvc -n YOUR_APP_NAMESPACE

# Check PVC events
kubectl describe pvc -n YOUR_APP_NAMESPACE YOUR_PVC_NAME | grep -A 10 Events
```

If the PVC shows `Lost` or `Pending`, the underlying storage has a problem — escalate immediately to your infrastructure team.

---

## Step 3 — Check connection saturation (for the warning alert)

```bash
# Query current active connections in Prometheus
# Open: http://localhost:9090 (port-forward if needed)
# Query:
# pg_stat_database_numbackends / pg_settings_max_connections * 100
```

If connections are saturated:

```bash
# Check which applications are holding the most connections
kubectl exec -n YOUR_APP_NAMESPACE YOUR_POSTGRES_POD_NAME -- \
  psql -U postgres -c "SELECT application_name, count(*) FROM pg_stat_activity GROUP BY application_name ORDER BY count DESC;"
```

If a specific service is holding too many connections, restart it:

```bash
kubectl rollout restart deployment/YOUR_MAIN_SERVICE_NAME -n YOUR_APP_NAMESPACE
```

---

## Step 4 — Attempt database restart (if pod is crashed)

```bash
# Restart the PostgreSQL deployment
kubectl rollout restart deployment/postgresql -n YOUR_APP_NAMESPACE
# OR if using StatefulSet (common for databases):
kubectl rollout restart statefulset/postgresql -n YOUR_APP_NAMESPACE

# Watch the restart
kubectl rollout status statefulset/postgresql -n YOUR_APP_NAMESPACE --timeout=3m
```

---

## Step 5 — Verify data integrity after recovery

After the database comes back up, verify the application services reconnect:

```bash
# Check app health
kubectl exec -n YOUR_APP_NAMESPACE deploy/YOUR_MAIN_SERVICE_NAME -- \
  curl -s http://localhost:9000/q/health/ready | python3 -m json.tool
# Expected: {"status":"UP"}
```

Open Prometheus UI and check: `pg_up` — expected value: `1`.

---

## Step 6 — Escalation

If the database does not recover within **5 minutes** of restart:
1. Do NOT attempt further manual intervention without DBA guidance
2. Alert the technical lead immediately
3. Capture: pod logs, PVC status, `kubectl describe` output

---

## Recovery confirmation

- `DatabaseDown` resolves when `pg_up == 1` is detected again
- `DatabaseConnectionSaturation` resolves when connections drop below threshold
- Verify in Prometheus UI → Alerts → both alerts state: `inactive`
