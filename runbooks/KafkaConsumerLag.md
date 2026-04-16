# Runbook: KafkaConsumerLagHigh

**Alert:** `KafkaConsumerLagHigh`  
**Severity:** Critical  
**Threshold:** Consumer group lag > `ALERT_KAFKA_LAG_THRESHOLD` messages for 5 minutes

---

## What this means

One or more Kafka consumer groups are falling behind — they are not processing messages as fast as they arrive.

In an event-driven system, this is the most dangerous type of silent failure: **no error appears in the logs**, but processes stop being triggered because their activation events are stuck in the queue.

## Business impact

- New process instances stop being created
- Timer-based or event-triggered steps never execute
- The system appears "stuck" from the user's perspective

---

## Step 1 — Identify which consumer group is lagging

Open Grafana → **Application Processes** → **Kafka Consumer Lag** panel.  
Note the consumer group name shown in the legend.

```bash
# List all Kafka consumer groups and their lag
kubectl exec -n YOUR_APP_NAMESPACE \
  deploy/YOUR_KAFKA_POD_NAME -- \
  bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe --all-groups \
  | grep -v "^$"
```

---

## Step 2 — Check if the consumer is running

```bash
# Check the service that owns the consumer group
kubectl get pods -n YOUR_APP_NAMESPACE | grep YOUR_JOBS_SERVICE_NAME

# Check its logs for errors
kubectl logs -n YOUR_APP_NAMESPACE \
  -l app=YOUR_JOBS_SERVICE_NAME \
  --tail=100 \
  | grep -i "error\|exception\|warn"
```

---

## Step 3 — Check Kafka broker health

```bash
# Check Kafka broker pods (if using Strimzi)
kubectl get pods -n YOUR_APP_NAMESPACE | grep kafka

# Check Kafka broker logs
kubectl logs -n YOUR_APP_NAMESPACE \
  -l strimzi.io/kind=Kafka \
  --tail=50
```

Open Prometheus UI → query:
```promql
kafka_server_brokerstate
```
Expected value: `3` (RunningAsBroker). Any other value indicates a broker problem.

---

## Step 4 — Restart the consumer if stuck

If the consumer pod is running but not processing (lag is growing, no errors in logs), it may be stuck in a rebalance or deadlock.

```bash
# Restart the jobs/consumer service
kubectl rollout restart deployment/YOUR_JOBS_SERVICE_NAME -n YOUR_APP_NAMESPACE

# Watch the rollout
kubectl rollout status deployment/YOUR_JOBS_SERVICE_NAME -n YOUR_APP_NAMESPACE

# After restart, check lag is decreasing
# Open Grafana → Kafka Consumer Lag panel — should trend downward
```

---

## Step 5 — Check for topic issues

```bash
# Describe the affected topic
kubectl exec -n YOUR_APP_NAMESPACE \
  deploy/YOUR_KAFKA_POD_NAME -- \
  bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --describe \
  --topic YOUR_TOPIC_NAME
```

Look for: under-replicated partitions, offline partitions, or a partition leader that is unavailable.

---

## Step 6 — Escalation

If lag is still growing after consumer restart and Kafka brokers are healthy:

1. Check if a large batch of messages caused a backlog (expected, will self-resolve)
2. Check disk space on Kafka broker nodes
3. Contact the technical lead with: consumer group name, lag value, Grafana screenshot

---

## Recovery confirmation

The alert resolves when the lag drops below the threshold.  
Confirm in Grafana — the **Kafka Consumer Lag** panel should trend to zero.
