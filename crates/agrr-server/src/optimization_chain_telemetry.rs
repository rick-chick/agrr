//! Plain-text optimization chain step telemetry for Cloud Logging (`textPayload` grep).

use std::time::Instant;

use agrr_adapters_gcs::{set_gcs_read_log_suffix, GcsIoSnapshot};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StepOutcome {
    Ok,
    Failed,
}

fn format_step_log(
    step: &str,
    plan_id: i64,
    duration_ms: u128,
    gcs_reads: u64,
    gcs_lists: u64,
    gcs_writes: u64,
    outcome: StepOutcome,
    error: Option<&str>,
) -> String {
    let outcome_str = match outcome {
        StepOutcome::Ok => "ok",
        StepOutcome::Failed => "failed",
    };
    match error {
        Some(err) => format!(
            "optimization_chain step={step} plan_id={plan_id} duration_ms={duration_ms} \
             gcs_reads={gcs_reads} gcs_lists={gcs_lists} gcs_writes={gcs_writes} \
             outcome={outcome_str} error={err}"
        ),
        None => format!(
            "optimization_chain step={step} plan_id={plan_id} duration_ms={duration_ms} \
             gcs_reads={gcs_reads} gcs_lists={gcs_lists} gcs_writes={gcs_writes} outcome={outcome_str}"
        ),
    }
}

pub struct StepTimer {
    started: Instant,
    gcs_before: GcsIoSnapshot,
    step: &'static str,
    plan_id: i64,
}

fn begin_step_scope(plan_id: i64, step: &'static str) {
    set_gcs_read_log_suffix(Some(format!(" plan_id={plan_id} step={step}")));
}

fn end_step_scope() {
    set_gcs_read_log_suffix(None);
}

impl StepTimer {
    pub fn start(plan_id: i64, step: &'static str) -> Self {
        begin_step_scope(plan_id, step);
        Self {
            started: Instant::now(),
            gcs_before: GcsIoSnapshot::capture(),
            step,
            plan_id,
        }
    }

    pub fn log(self, outcome: StepOutcome, error: Option<&str>) {
        let duration_ms = self.started.elapsed().as_millis();
        let (gcs_reads, gcs_lists, gcs_writes) = self.gcs_before.delta_since();
        let message = format_step_log(
            self.step,
            self.plan_id,
            duration_ms,
            gcs_reads,
            gcs_lists,
            gcs_writes,
            outcome,
            error,
        );
        // Cloud Run surfaces stderr as textPayload; tracing::info alone is not grep-friendly in production.
        eprintln!("{message}");
    }
}

impl Drop for StepTimer {
    fn drop(&mut self) {
        end_step_scope();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_adapters_gcs::{gcs_read_log_suffix_snapshot, set_gcs_read_log_suffix};

    #[test]
    fn format_step_log_includes_grep_friendly_prefix_and_fields() {
        let line = format_step_log(
            "fetch_weather_data",
            729,
            4521,
            21,
            1,
            0,
            StepOutcome::Ok,
            None,
        );
        assert!(line.starts_with("optimization_chain step=fetch_weather_data"));
        assert!(line.contains("plan_id=729"));
        assert!(line.contains("duration_ms=4521"));
        assert!(line.contains("gcs_reads=21"));
        assert!(line.contains("gcs_lists=1"));
        assert!(line.contains("gcs_writes=0"));
        assert!(line.contains("outcome=ok"));
        assert!(!line.contains("error="));
    }

    #[test]
    fn format_step_log_matches_production_grep_pattern_on_predict_failure() {
        let line = format_step_log(
            "weather_prediction",
            732,
            63_840,
            21,
            1,
            0,
            StepOutcome::Failed,
            Some("Expected 206 days from 2026-06-09 to 2026-12-31, but received 205 days."),
        );
        assert!(line.starts_with("optimization_chain step=weather_prediction"));
        assert!(line.contains("plan_id=732"));
        assert!(line.contains("outcome=failed"));
        assert!(line.contains("error=Expected 206 days"));
    }

    #[test]
    fn step_timer_clears_gcs_read_log_suffix_on_drop_without_log() {
        set_gcs_read_log_suffix(None);
        {
            let _timer = StepTimer::start(99, "fetch_weather_data");
            assert_eq!(
                gcs_read_log_suffix_snapshot(),
                Some(" plan_id=99 step=fetch_weather_data".to_string())
            );
        }
        assert_eq!(gcs_read_log_suffix_snapshot(), None);
    }

    #[test]
    fn step_timer_clears_gcs_read_log_suffix_after_log() {
        set_gcs_read_log_suffix(None);
        StepTimer::start(100, "bootstrap").log(StepOutcome::Ok, None);
        assert_eq!(gcs_read_log_suffix_snapshot(), None);
    }
}
