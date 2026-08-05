//! OpenTelemetry / tracing bootstrap for agrr-server.
//!
//! Export is opt-in via [`otel_export_enabled`]. Local Docker and contract tests stay no-op
//! (no external collector) while HTTP spans and optimization-chain correlation still work.

use std::sync::OnceLock;

use opentelemetry::trace::TracerProvider as _;
use opentelemetry::KeyValue;
use opentelemetry_sdk::trace::{RandomIdGenerator, Sampler, TracerProvider};
use opentelemetry_sdk::Resource;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;
use tracing_subscriber::{EnvFilter, Registry};

static TRACE_ID_HEX: OnceLock<fn() -> Option<String>> = OnceLock::new();

/// Whether OTLP export should be initialized (false in tests and local Docker by default).
pub fn otel_export_enabled() -> bool {
    if truthy_env("OTEL_SDK_DISABLED") {
        return false;
    }
    if truthy_env("AGRR_OTEL_ENABLED") {
        return true;
    }
    std::env::var("OTEL_EXPORTER_OTLP_ENDPOINT")
        .map(|v| !v.trim().is_empty())
        .unwrap_or(false)
}

fn truthy_env(name: &str) -> bool {
    std::env::var(name)
        .map(|v| {
            let v = v.trim().to_ascii_lowercase();
            matches!(v.as_str(), "1" | "true" | "yes" | "on")
        })
        .unwrap_or(false)
}

fn service_name() -> String {
    std::env::var("OTEL_SERVICE_NAME")
        .ok()
        .filter(|v| !v.trim().is_empty())
        .unwrap_or_else(|| "agrr-server".to_string())
}

/// Initialize tracing (idempotent). Call once at process start.
pub fn init() {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    let fmt_layer = tracing_subscriber::fmt::layer();

    if otel_export_enabled() {
        let provider = build_tracer_provider();
        let tracer = provider.tracer(service_name());
        let otel_layer = tracing_opentelemetry::layer().with_tracer(tracer);
        let _ = Registry::default()
            .with(filter)
            .with(fmt_layer)
            .with(otel_layer)
            .try_init();
        let _ = TRACE_ID_HEX.set(trace_id_from_otel_span);
    } else {
        let _ = Registry::default()
            .with(filter)
            .with(fmt_layer)
            .try_init();
        let _ = TRACE_ID_HEX.set(trace_id_from_tracing_span);
    }
}

fn build_tracer_provider() -> TracerProvider {
    let exporter = opentelemetry_otlp::SpanExporter::builder()
        .with_tonic()
        .build()
        .expect("OTLP span exporter");

    TracerProvider::builder()
        .with_sampler(Sampler::ParentBased(Box::new(Sampler::AlwaysOn)))
        .with_id_generator(RandomIdGenerator::default())
        .with_resource(Resource::new(vec![KeyValue::new(
            "service.name",
            service_name(),
        )]))
        .with_batch_exporter(exporter, opentelemetry_sdk::runtime::Tokio)
        .build()
}

/// Hex trace id for the active span, if any.
pub fn current_trace_id_hex() -> Option<String> {
    TRACE_ID_HEX
        .get()
        .map(|f| f())
        .unwrap_or(None)
}

fn trace_id_from_otel_span() -> Option<String> {
    use opentelemetry::trace::TraceContextExt;
    use tracing_opentelemetry::OpenTelemetrySpanExt;

    let span = tracing::Span::current();
    let context = span.context();
    let otel_span = context.span();
    let span_context = otel_span.span_context();
    if span_context.is_valid() {
        Some(span_context.trace_id().to_string())
    } else {
        None
    }
}

fn trace_id_from_tracing_span() -> Option<String> {
    let span = tracing::Span::current();
    if span.is_none() {
        return None;
    }
    let id = span.id()?;
    Some(format!("{:016x}", id.into_u64()))
}

/// Parent span for an optimization chain enqueued from an HTTP request.
pub fn optimization_chain_span(plan_id: i64, channel: &str) -> tracing::Span {
    tracing::info_span!(
        "optimization_chain",
        plan_id,
        channel,
        otel.name = "optimization_chain",
    )
}

/// Run a chain step inside a linked child span.
pub fn optimization_step_span(plan_id: i64, step: &'static str) -> tracing::Span {
    tracing::info_span!(
        "optimization_chain_step",
        plan_id,
        step,
        otel.name = step,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn otel_export_disabled_by_default_without_env() {
        // Tests do not set AGRR_OTEL_ENABLED / OTEL_EXPORTER_OTLP_ENDPOINT.
        assert!(!otel_export_enabled());
    }

    #[test]
    fn current_trace_id_none_outside_span() {
        assert_eq!(current_trace_id_hex(), None);
    }

    #[test]
    fn current_trace_id_present_inside_span() {
        init();
        let span = tracing::info_span!("test_span");
        let _guard = span.enter();
        assert!(current_trace_id_hex().is_some());
    }
}
