package com.yourorg.poc.service;

// ── T-04: Manual OpenTelemetry spans ──────────────────────────────────────────
//
// WHY MANUAL SPANS:
// Quarkus auto-instruments HTTP calls, JDBC queries and CDI beans.
// But it doesn't know your business steps (e.g. "check eligibility" or
// "reserve resource"). Manual spans add those business checkpoints to traces
// so you can see in Jaeger exactly where time is spent inside a process.
//
// HOW TO ADAPT:
// 1. Rename this class to match your actual service
// 2. Replace "your-resource-id" and method names with your business concepts
// 3. Inject ProcessMetrics if you want to combine tracing + counters
// ─────────────────────────────────────────────────────────────────────────────

import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.api.trace.Tracer;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

@ApplicationScoped
public class ExampleService {

    @Inject
    Tracer tracer;

    @Inject
    ProcessMetrics metrics;   // from T-01 — optional, remove if not needed

    /**
     * Example of a method that is both traced (OTel span) and counted (Micrometer).
     *
     * CHANGE ME: rename to your actual business operation
     * e.g. activateESIM(), provisionLine(), createOrder()
     */
    public void executeProcess(String resourceId) {

        // Create a child span for this business operation.
        // This span will appear nested under the parent HTTP span in Jaeger.
        Span span = tracer.spanBuilder("your-operation-name")
            // Add attributes — these are searchable filters in Jaeger
            // CHANGE ME: use attribute names relevant to your domain
            .setAttribute("resource.id", resourceId)
            .setAttribute("resource.type", "your-resource-type")
            .startSpan();

        // Record the process start in Micrometer counter
        metrics.recordStart();

        try (var scope = span.makeCurrent()) {

            // ── Step 1: first sub-operation ───────────────────────────────────
            // Create a nested span for a specific sub-step
            Span step1 = tracer.spanBuilder("step1-check-eligibility")
                .setAttribute("resource.id", resourceId)
                .startSpan();
            try (var s1 = step1.makeCurrent()) {
                // CHANGE ME: your actual step 1 logic
                performStep1(resourceId);
                step1.setStatus(StatusCode.OK);
            } catch (Exception e) {
                step1.setStatus(StatusCode.ERROR, e.getMessage());
                step1.recordException(e);
                throw e;
            } finally {
                step1.end();
            }

            // ── Step 2: second sub-operation ──────────────────────────────────
            Span step2 = tracer.spanBuilder("step2-execute-action")
                .setAttribute("resource.id", resourceId)
                .startSpan();
            try (var s2 = step2.makeCurrent()) {
                // CHANGE ME: your actual step 2 logic
                performStep2(resourceId);
                step2.setStatus(StatusCode.OK);
            } catch (Exception e) {
                step2.setStatus(StatusCode.ERROR, e.getMessage());
                step2.recordException(e);
                throw e;
            } finally {
                step2.end();
            }

            // Mark the parent span as successful
            span.setStatus(StatusCode.OK);
            metrics.recordComplete();

        } catch (Exception e) {
            // Mark the parent span as failed — this makes it findable
            // in Jaeger using the filter: error=true
            span.setStatus(StatusCode.ERROR, e.getMessage());
            span.recordException(e);
            metrics.recordError();
            throw new RuntimeException("Process failed for resource: " + resourceId, e);
        } finally {
            span.end();
        }
    }

    // ── Private step implementations ───────────────────────────────────────────
    // CHANGE ME: replace with your actual logic

    private void performStep1(String resourceId) {
        // e.g. call an external eligibility API
        // e.g. query the database
        // e.g. validate business rules
    }

    private void performStep2(String resourceId) {
        // e.g. call the provisioning API
        // e.g. update the database
        // e.g. send a Kafka event
    }
}
