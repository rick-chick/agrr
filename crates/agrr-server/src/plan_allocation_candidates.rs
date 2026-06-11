//! Plan allocation candidates for add_crop (Ruby `PlanAllocationCandidatesInteractor` edge wiring).

use std::collections::HashMap;

use agrr_adapters_agrr::PlanAllocationCandidatesAgrrDaemonGateway;
use agrr_adapters_sqlite::PlanAllocationAdjustReadSqliteGateway;
use agrr_domain::crop::dtos::AddCropCropSnapshot;
use agrr_domain::cultivation_plan::dtos::CultivationPlanRestAuth;
use agrr_domain::cultivation_plan::errors::AllocationNoCandidatesError;
use agrr_domain::cultivation_plan::gateways::{
    PlanAllocationAdjustReadGateway, PlanAllocationCandidatesGateway,
};
use agrr_domain::cultivation_plan::mappers::PlanAllocationAdjustAgrrPayloadMapper;
use agrr_domain::cultivation_plan::ports::{PlanAllocationCandidateBest, PlanAllocationCandidatesPort};
use agrr_domain::cultivation_plan::helpers::parse_iso_date;
use agrr_domain::shared::ports::{ClockPort, LoggerPort};
use agrr_domain::weather_data::WeatherPredictionError;
use serde_json::Value;
use time::Date;

use crate::adapters::{StderrLogger, SystemClock};
use crate::adjust_weather_prediction::resolve_weather_for_candidates;
use crate::state::AppState;

pub struct PlanAllocationCandidatesService<'a> {
    state: &'a AppState,
    read_gateway: &'a PlanAllocationAdjustReadSqliteGateway,
    candidates_gateway: &'a PlanAllocationCandidatesAgrrDaemonGateway,
    clock: SystemClock,
    logger: StderrLogger,
}

impl<'a> PlanAllocationCandidatesService<'a> {
    pub fn new(
        state: &'a AppState,
        read_gateway: &'a PlanAllocationAdjustReadSqliteGateway,
        candidates_gateway: &'a PlanAllocationCandidatesAgrrDaemonGateway,
    ) -> Self {
        Self {
            state,
            read_gateway,
            candidates_gateway,
            clock: SystemClock,
            logger: StderrLogger,
        }
    }
}

impl PlanAllocationCandidatesPort for PlanAllocationCandidatesService<'_> {
    fn call(
        &self,
        _auth: &CultivationPlanRestAuth,
        plan_id: i64,
        crop: &AddCropCropSnapshot,
        field_id: &str,
        display_range: &HashMap<String, Value>,
        ui_filter_context: &HashMap<String, Value>,
    ) -> Result<
        Option<PlanAllocationCandidateBest>,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        let snapshot = self
            .read_gateway
            .find_adjust_read_snapshot_by_plan_id(plan_id)
            .map_err(|err| {
                self.logger
                    .error(&format!("❌ [Candidates] snapshot load failed: {err}"));
                err
            })?;

        if snapshot.farm_without_weather_location {
            self.logger.error("❌ [Candidates] No weather location found");
            return Err(Box::new(WeatherPredictionError::WeatherLocationRequired));
        }

        log_candidate_window(display_range, ui_filter_context, &self.logger);

        let current_allocation =
            PlanAllocationAdjustAgrrPayloadMapper::to_current_allocation(&snapshot, &[], &self.logger);
        let fields = PlanAllocationAdjustAgrrPayloadMapper::to_fields_config(&snapshot);
        let crops = PlanAllocationAdjustAgrrPayloadMapper::to_crops_config(&snapshot, None);
        let rule_seed = format!(
            "{:08x}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos() as u32
        );
        let interaction_rules =
            PlanAllocationAdjustAgrrPayloadMapper::to_interaction_rules(&snapshot, &rule_seed);
        let interaction_rules_value = if interaction_rules.is_empty() {
            None
        } else {
            Some(serde_json::json!({ "rules": interaction_rules }))
        };

        let display_start = display_range
            .get("start_date")
            .or_else(|| display_range.get(":start_date"))
            .and_then(|v| v.as_str())
            .and_then(parse_iso_date);
        let display_end = display_range
            .get("end_date")
            .or_else(|| display_range.get(":end_date"))
            .and_then(|v| v.as_str())
            .and_then(parse_iso_date);

        let window = resolve_candidates_planning_window(
            display_start,
            display_end,
            snapshot.planning_period_boundaries.planning_start_date,
            snapshot.planning_period_boundaries.planning_end_date,
            snapshot
                .cultivation_plan_weather_dto
                .prediction_target_end_date,
            self.clock.today(),
        );
        let candidates_start = window.candidates_start;
        let candidates_end = window.candidates_end;
        let target_end_date = window.weather_target_end;

        self.logger.info(&format!(
            "📅 [Candidates] Planning period: {candidates_start} ~ {candidates_end} (weather_target_end={target_end_date})"
        ));

        let weather_value = resolve_weather_for_candidates(
            self.state,
            plan_id,
            &snapshot.cultivation_plan_weather_dto,
            target_end_date,
            &self.logger,
        )
        .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)?;

        let candidates = match self.candidates_gateway.candidates(
            &current_allocation,
            &fields,
            &crops,
            &Value::String(crop.id.to_string()),
            &weather_value,
            candidates_start,
            candidates_end,
            interaction_rules_value.as_ref(),
        ) {
            Ok(c) => c,
            Err(err) if err.downcast_ref::<AllocationNoCandidatesError>().is_some() => {
                self.logger
                    .info(&format!("ℹ️ [Candidates] No allocation candidates: {err}"));
                return Ok(None);
            }
            Err(err) => {
                self.logger
                    .error(&format!("❌ [Candidates] agrr candidates failed: {err}"));
                return Err(err);
            }
        };

        Ok(select_best_candidate(
            &candidates,
            field_id,
            candidates_start,
            &self.logger,
        ))
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct CandidatesPlanningWindow {
    candidates_start: Date,
    candidates_end: Date,
    weather_target_end: Date,
}

/// UI display range can extend past the planning horizon (gantt visible window).
/// AGRR candidate search may use the wider window, but weather prediction must
/// match the plan's prediction target — same as adjust/optimize flows.
fn resolve_candidates_planning_window(
    display_start: Option<Date>,
    display_end: Option<Date>,
    planning_start: Option<Date>,
    planning_end: Option<Date>,
    prediction_target_end: Option<Date>,
    today: Date,
) -> CandidatesPlanningWindow {
    let fallback_start = planning_start.unwrap_or(today);
    let candidates_start = display_start.unwrap_or(fallback_start);
    let base_end = planning_end.unwrap_or_else(|| {
        Date::from_calendar_date(candidates_start.year() + 2, time::Month::December, 31)
            .unwrap_or(candidates_start)
    });
    let candidates_end = display_end.map(|d| d.max(base_end)).unwrap_or(base_end);
    let weather_target_end = prediction_target_end.unwrap_or(base_end);
    CandidatesPlanningWindow {
        candidates_start,
        candidates_end,
        weather_target_end,
    }
}

fn log_candidate_window(
    display_range: &HashMap<String, Value>,
    ui_filter_context: &HashMap<String, Value>,
    logger: &StderrLogger,
) {
    let display_start = display_range
        .get("start_date")
        .or_else(|| display_range.get(":start_date"))
        .and_then(|v| v.as_str());
    let display_end = display_range
        .get("end_date")
        .or_else(|| display_range.get(":end_date"))
        .and_then(|v| v.as_str());
    if display_start.is_some() || display_end.is_some() {
        logger.info(&format!(
            "📅 [Candidates] UI表示範囲: start={} end={}",
            display_start.unwrap_or("N/A"),
            display_end.unwrap_or("N/A")
        ));
    } else {
        logger.info("📅 [Candidates] UI表示範囲: not provided");
    }
    let filters = if ui_filter_context.is_empty() {
        "none".to_string()
    } else {
        ui_filter_context
            .iter()
            .map(|(k, v)| format!("{k}={v}"))
            .collect::<Vec<_>>()
            .join(", ")
    };
    logger.info(&format!("📋 [Candidates] UI filters: {filters}"));
}

fn select_best_candidate(
    candidates: &[Value],
    preferred_field_id: &str,
    lower_bound: Date,
    logger: &StderrLogger,
) -> Option<PlanAllocationCandidateBest> {
    let preferred: Option<i64> = preferred_field_id.parse().ok();
    let mut valid: Vec<&Value> = candidates
        .iter()
        .filter(|c| {
            c.get("start_date")
                .and_then(|v| v.as_str())
                .and_then(parse_iso_date)
                .map(|d| d >= lower_bound)
                .unwrap_or(false)
        })
        .collect();

    logger.info(&format!(
        "🔍 [Candidates] Total: {}, Valid: {} (filtered before {lower_bound})",
        candidates.len(),
        valid.len()
    ));

    if valid.is_empty() {
        logger.warn("⚠️ [Candidates] No candidates after date filter");
        return None;
    }

    if let Some(fid) = preferred {
        let field_pool: Vec<_> = valid
            .iter()
            .filter(|c| c.get("field_id").and_then(|v| v.as_i64()) == Some(fid))
            .copied()
            .collect();
        if !field_pool.is_empty() {
            valid = field_pool;
        }
    }

    let best = valid.iter().max_by(|a, b| {
        let pa = a
            .get("profit")
            .or_else(|| a.get("expected_profit"))
            .and_then(|v| v.as_f64())
            .unwrap_or(0.0);
        let pb = b
            .get("profit")
            .or_else(|| b.get("expected_profit"))
            .and_then(|v| v.as_f64())
            .unwrap_or(0.0);
        pa.partial_cmp(&pb).unwrap_or(std::cmp::Ordering::Equal)
    })?;

    let field_id = best
        .get("field_id")
        .map(|v| {
            v.as_i64()
                .map(|n| n.to_string())
                .or_else(|| v.as_str().map(|s| s.to_string()))
        })
        .flatten()?;
    let start_date = best
        .get("start_date")
        .and_then(|v| v.as_str())
        .map(|s| s.chars().take(10).collect::<String>())?;

    Some(PlanAllocationCandidateBest {
        field_id,
        start_date,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use time::Month;

    fn d(y: i32, m: u8, day: u8) -> Date {
        Date::from_calendar_date(y, Month::try_from(m).unwrap(), day).unwrap()
    }

    #[test]
    fn weather_target_uses_planning_horizon_when_display_end_extends_past_it() {
        let window = resolve_candidates_planning_window(
            Some(d(2026, 1, 1)),
            Some(d(2028, 1, 1)),
            Some(d(2026, 1, 1)),
            Some(d(2027, 12, 31)),
            Some(d(2027, 12, 31)),
            d(2026, 6, 11),
        );
        assert_eq!(window.candidates_end, d(2028, 1, 1));
        assert_eq!(window.weather_target_end, d(2027, 12, 31));
    }

    #[test]
    fn weather_target_falls_back_to_planning_end_without_prediction_target() {
        let window = resolve_candidates_planning_window(
            Some(d(2026, 1, 1)),
            Some(d(2028, 1, 1)),
            Some(d(2026, 1, 1)),
            Some(d(2027, 12, 31)),
            None,
            d(2026, 6, 11),
        );
        assert_eq!(window.weather_target_end, d(2027, 12, 31));
    }

    #[test]
    fn weather_target_uses_planning_end_when_display_range_omitted() {
        let window = resolve_candidates_planning_window(
            None,
            None,
            Some(d(2026, 1, 1)),
            Some(d(2027, 12, 31)),
            None,
            d(2026, 6, 11),
        );
        assert_eq!(window.candidates_start, d(2026, 1, 1));
        assert_eq!(window.candidates_end, d(2027, 12, 31));
        assert_eq!(window.weather_target_end, d(2027, 12, 31));
    }
}
