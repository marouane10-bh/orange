package com.yourorg.poc.metrics;

// ── T-01: Custom business metrics ─────────────────────────────────────────────
//
// WHY THIS CLASS EXISTS:
// Micrometer automatically exposes JVM and HTTP metrics.
// It does NOT know about your business processes (e.g. how many eSIM orders
// were started, completed, or failed). This class registers those counters
// so they appear in Grafana and trigger the HighErrorRate alert.
//
// HOW TO USE:
// 1. Rename the counter names to match your process type
//    (e.g. "esim.activation" → "order.provisioning")
// 2. Inject this class wherever your process starts/completes/errors
// 3. Call recordStart(), recordComplete(), or recordError()
//
// HOW TO ADD A NEW METRIC TYPE:
// Copy the Counter pattern and change the builder name and tags.
// For timing a process, use Timer.builder(...) instead of Counter.builder(...)
// ─────────────────────────────────────────────────────────────────────────────

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

@ApplicationScoped
public class ProcessMetrics {

    // ── Counters ──────────────────────────────────────────────────────────────
    // A Counter is a monotonically increasing number. It never decreases.
    // Use rate() in PromQL to get the rate of increase per second.

    private final Counter processStarted;
    private final Counter processCompleted;
    private final Counter processError;

    // ── Timer ─────────────────────────────────────────────────────────────────
    // A Timer records both count and duration.
    // Use histogram_quantile() in PromQL to get p50/p95/p99 durations.

    private final Timer processDuration;

    @Inject
    public ProcessMetrics(MeterRegistry registry) {

        // CHANGE ME: replace "your-process-type" with your actual process name
        // This tag appears as a label in Prometheus and Grafana filters
        final String processType = "your-process-type";

        this.processStarted = Counter.builder("process.started")
            .tag("type", processType)
            .description("Total number of processes started")
            .register(registry);

        this.processCompleted = Counter.builder("process.completed")
            .tag("type", processType)
            .description("Total number of processes completed successfully")
            .register(registry);

        this.processError = Counter.builder("process.error")
            .tag("type", processType)
            .description("Total number of processes that ended in error")
            .register(registry);

        this.processDuration = Timer.builder("process.duration")
            .tag("type", processType)
            .description("Duration of process execution from start to end")
            .publishPercentiles(0.5, 0.95, 0.99)  // p50, p95, p99
            .register(registry);
    }

    // ── Public API ────────────────────────────────────────────────────────────

    /** Call this when a new process instance is created. */
    public void recordStart() {
        processStarted.increment();
    }

    /** Call this when a process instance completes successfully. */
    public void recordComplete() {
        processCompleted.increment();
    }

    /** Call this when a process instance ends in error. */
    public void recordError() {
        processError.increment();
    }

    /**
     * Use this to time a complete process execution.
     *
     * Example:
     *   metrics.time(() -> {
     *       // your process logic here
     *   });
     */
    public void time(Runnable processExecution) {
        processDuration.record(processExecution);
    }
}
