//! Ruby: `Domain::CultivationPlan::Interactors::EntryScheduleOptimizeInteractor`

use std::collections::BTreeMap;

use serde_json::{json, Value};

use crate::cultivation_plan::calculators::entry_schedule_stage_gdd_scaler;
use crate::cultivation_plan::errors::EntryScheduleOptimizationError;
use crate::cultivation_plan::gateways::{
    EntryScheduleCropGateway, EntryScheduleOptimizationGateway,
};
use crate::cultivation_plan::interactors::entry_schedule::{
    stage_role_resolver::StageRoleResolver, DateRange, WindowServiceResult, CropStageSnapshot,
};
use crate::cultivation_plan::normalizers::entry_schedule_weather_payload_normalizer;
use crate::shared::hash::present;
use crate::shared::ports::{ClockPort, CropAgrrRequirementBuilderPort, CropAgrrRequirementSource, LoggerPort};

pub trait EntryScheduleOptimizeCrop: CropAgrrRequirementSource {
    fn crop_id(&self) -> i64;
    fn crop_name(&self) -> &str;
    fn crop_variety(&self) -> Option<&str>;
}

pub struct EntryScheduleOptimizeInteractor<'a, CG, B, G, Cl, L> {
    crop: &'a dyn EntryScheduleOptimizeCrop,
    weather_payload: Value,
    crop_gateway: &'a CG,
    crop_agrr_requirement_builder: &'a B,
    entry_schedule_optimization_gateway: &'a G,
    clock: &'a Cl,
    logger: Option<&'a L>,
    agrr_enabled: bool,
}

impl<'a, CG, B, G, Cl, L> EntryScheduleOptimizeInteractor<'a, CG, B, G, Cl, L>
where
    CG: EntryScheduleCropGateway,
    B: CropAgrrRequirementBuilderPort,
    G: EntryScheduleOptimizationGateway,
    Cl: ClockPort,
    L: LoggerPort,
{
    pub fn new(
        crop: &'a dyn EntryScheduleOptimizeCrop,
        weather_payload: Value,
        crop_gateway: &'a CG,
        crop_agrr_requirement_builder: &'a B,
        entry_schedule_optimization_gateway: &'a G,
        clock: &'a Cl,
        logger: Option<&'a L>,
        agrr_enabled: bool,
    ) -> Self {
        Self {
            crop,
            weather_payload: entry_schedule_weather_payload_normalizer::call(Some(&weather_payload)),
            crop_gateway,
            crop_agrr_requirement_builder,
            entry_schedule_optimization_gateway,
            clock,
            logger,
            agrr_enabled,
        }
    }

    pub fn call(&self) -> WindowServiceResult {
        if !self.agrr_enabled {
            return self.failed_result("disabled");
        }

        let Some((eval_start, eval_end)) = self.evaluation_range() else {
            return self.failed_result("insufficient_weather");
        };

        let Some(weather_for_file) = self.weather_hash_for_agrr() else {
            return self.failed_result("insufficient_weather");
        };

        let requirement = self.crop_agrr_requirement_builder.build_from(self.crop);
        let crop_requirement = entry_schedule_stage_gdd_scaler::call(&requirement, None, None);

        match self.entry_schedule_optimization_gateway.optimize_period(
            self.crop.crop_name(),
            self.crop_variety(),
            &weather_for_file,
            eval_start,
            eval_end,
            &crop_requirement,
            &json!({}),
        ) {
            Ok(parsed) => self.map_success(parsed, &weather_for_file),
            Err(err) if err.downcast_ref::<EntryScheduleOptimizationError>().is_some() => {
                let e = err.downcast_ref::<EntryScheduleOptimizationError>().unwrap();
                self.log_warn(&format!("optimize: {}", e.message));
                self.failed_result(&e.error_key)
            }
            Err(err) => {
                self.log_error(&err.to_string());
                self.failed_result("crop_requirement_error")
            }
        }
    }

    pub fn evaluation_range(&self) -> Option<(time::Date, time::Date)> {
        let dates = self.daily_dates_from_payload();
        if dates.is_empty() {
            return None;
        }
        let data_min = *dates.iter().min()?;
        let data_max = *dates.iter().max()?;
        let today = self.clock.today();
        let y = today.year();
        let ideal_start = time::Date::from_calendar_date(y - 1, time::Month::June, 1).ok()?;
        let ideal_end = time::Date::from_calendar_date(y + 1, time::Month::June, 30).ok()?;
        let eval_start = data_min.max(ideal_start);
        let eval_end = data_max.min(ideal_end);
        if eval_start > eval_end {
            return None;
        }
        Some((eval_start, eval_end))
    }

    fn crop_variety(&self) -> Option<&str> {
        self.crop
            .crop_variety()
            .filter(|v| present(&Value::String(v.to_string())))
            .or(Some("general"))
    }

    fn map_success(
        &self,
        parsed: Value,
        weather_for_file: &Value,
    ) -> WindowServiceResult {
        let start_d = parsed
            .get("start_date")
            .and_then(parse_date_value);
        let end_d = parsed
            .get("completion_date")
            .and_then(parse_date_value);
        let (Some(start_d), Some(end_d)) = (start_d, end_d) else {
            return self.failed_result("invalid_response");
        };
        if end_d < start_d {
            return self.failed_result("invalid_response");
        }

        let stage_rows = self
            .crop_gateway
            .entry_schedule_ordered_stage_rows(self.crop.crop_id())
            .unwrap_or_default();
        let sow_st = StageRoleResolver::sowing_stage(&stage_rows);
        let tr_st = StageRoleResolver::transplant_stage(&stage_rows);
        let daily_count = weather_for_file
            .get("data")
            .and_then(|v| v.as_array())
            .map(|a| a.len())
            .unwrap_or(0);

        let mut reason_parts = BTreeMap::new();
        reason_parts.insert("source".into(), json!("agrr_optimize_period"));
        reason_parts.insert("rule".into(), json!("agrr_optimize_period"));
        reason_parts.insert("optimal_start_date".into(), json!(start_d.to_string()));
        reason_parts.insert("completion_date".into(), json!(end_d.to_string()));
        if let Some(days) = parsed.get("days") {
            reason_parts.insert("growth_days".into(), days.clone());
        }
        if let Some(gdd) = parsed.get("gdd") {
            reason_parts.insert("gdd".into(), gdd.clone());
        }
        if let Some(cost) = parsed.get("cost") {
            reason_parts.insert("total_cost".into(), cost.clone());
        }
        reason_parts.insert("days_evaluated".into(), json!(daily_count));
        if let Some(s) = sow_st.as_ref() {
            reason_parts.insert("sowing_stage_name".into(), json!(s.name.clone()));
        }
        if let Some(t) = tr_st.as_ref() {
            reason_parts.insert("transplant_stage_name".into(), json!(t.name.clone()));
        }

        WindowServiceResult {
            eligible: true,
            sowing_windows: vec![DateRange {
                start_date: start_d,
                end_date: end_d,
            }],
            transplant_windows: vec![DateRange {
                start_date: start_d,
                end_date: end_d,
            }],
            reason_parts,
            sowing_stage_id: sow_st.map(|s| s.id),
            transplant_stage_id: tr_st.map(|s| s.id),
            weather_end_date: self.extract_weather_end(),
        }
    }

    fn weather_hash_for_agrr(&self) -> Option<Value> {
        let h = &self.weather_payload;
        let data = h.get("data")?.as_array()?;
        if data.is_empty() {
            return None;
        }
        let mut core = json!({});
        for key in ["latitude", "longitude", "elevation", "timezone", "data"] {
            if let Some(v) = h.get(key) {
                core[key] = v.clone();
            }
        }
        let lat = core.get("latitude").unwrap_or(&Value::Null);
        let lon = core.get("longitude").unwrap_or(&Value::Null);
        if !present(lat) || !present(lon) {
            return None;
        }
        Some(core)
    }

    fn daily_dates_from_payload(&self) -> Vec<time::Date> {
        let data = match self.weather_payload.get("data").and_then(|v| v.as_array()) {
            Some(d) => d,
            None => return vec![],
        };
        data.iter()
            .filter_map(|row| {
                let raw = row
                    .get("time")
                    .or_else(|| row.get("date"))
                    .and_then(|v| v.as_str())?;
                crate::cultivation_plan::helpers::parse_iso_date(raw)
            })
            .collect()
    }

    fn extract_weather_end(&self) -> Option<time::Date> {
        self.daily_dates_from_payload().into_iter().max()
    }

    fn failed_result(&self, error_key: &str) -> WindowServiceResult {
        let mut reason_parts = BTreeMap::new();
        reason_parts.insert("source".into(), json!("agrr_failed"));
        reason_parts.insert("error_key".into(), json!(error_key));
        WindowServiceResult {
            eligible: false,
            sowing_windows: vec![],
            transplant_windows: vec![],
            reason_parts,
            sowing_stage_id: None,
            transplant_stage_id: None,
            weather_end_date: self.extract_weather_end(),
        }
    }

    fn log_warn(&self, message: &str) {
        if let Some(logger) = self.logger {
            logger.warn(&format!("[EntryScheduleOptimizeInteractor] {message}"));
        }
    }

    fn log_error(&self, message: &str) {
        if let Some(logger) = self.logger {
            logger.error(&format!("[EntryScheduleOptimizeInteractor] {message}"));
        }
    }
}

fn parse_date_value(value: &Value) -> Option<time::Date> {
    match value {
        Value::String(s) => crate::cultivation_plan::helpers::parse_iso_date(s),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cultivation_plan::interactors::entry_schedule::temperature_requirement_snapshot::TemperatureRequirementSnapshot;
    use std::sync::{Arc, Mutex};
    use time::macros::date;

    struct TestCrop {
        id: i64,
        name: String,
        variety: Option<String>,
    }

    impl CropAgrrRequirementSource for TestCrop {}
    impl EntryScheduleOptimizeCrop for TestCrop {
        fn crop_id(&self) -> i64 {
            self.id
        }
        fn crop_name(&self) -> &str {
            &self.name
        }
        fn crop_variety(&self) -> Option<&str> {
            self.variety.as_deref()
        }
    }

    struct FakeClock {
        today_val: time::Date,
    }

    impl ClockPort for FakeClock {
        fn today(&self) -> time::Date {
            self.today_val
        }
        fn now(&self) -> time::OffsetDateTime {
            time::OffsetDateTime::UNIX_EPOCH
        }
    }

    struct StubBuilder;
    impl CropAgrrRequirementBuilderPort for StubBuilder {
        fn build_from(&self, _: &dyn CropAgrrRequirementSource) -> Value {
            json!({
                "stage_requirements": [
                    { "thermal": { "required_gdd": 800.0 } },
                    { "thermal": { "required_gdd": 800.0 } }
                ]
            })
        }
    }

    struct StubCropGateway {
        rows: Vec<CropStageSnapshot>,
    }

    impl EntryScheduleCropGateway for StubCropGateway {
        fn entry_schedule_ordered_stage_rows(
            &self,
            _: i64,
        ) -> Result<Vec<CropStageSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.rows.clone())
        }
    }

    enum StubOptimizeOutcome {
        Ok(Value),
        Err(EntryScheduleOptimizationError),
    }

    struct StubOptimizationGateway {
        outcome: StubOptimizeOutcome,
        captured_requirement: Arc<Mutex<Option<Value>>>,
    }

    impl EntryScheduleOptimizationGateway for StubOptimizationGateway {
        fn optimize_period(
            &self,
            _: &str,
            _: Option<&str>,
            _: &Value,
            _: time::Date,
            _: time::Date,
            crop_requirement: &Value,
            _: &Value,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            *self.captured_requirement.lock().unwrap() = Some(crop_requirement.clone());
            match &self.outcome {
                StubOptimizeOutcome::Ok(v) => Ok(v.clone()),
                StubOptimizeOutcome::Err(e) => Err(Box::new(e.clone())),
            }
        }
    }

    fn weather_rows() -> Value {
        json!({
            "latitude": 35.0,
            "longitude": 139.0,
            "data": [
                { "time": "2026-05-01", "temperature_2m_min": 8.0, "temperature_2m_max": 22.0, "temperature_2m_mean": 15.0 },
                { "time": "2026-05-02", "temperature_2m_min": 8.0, "temperature_2m_max": 22.0, "temperature_2m_mean": 15.0 },
                { "time": "2026-05-03", "temperature_2m_min": 8.0, "temperature_2m_max": 22.0, "temperature_2m_mean": 15.0 }
            ]
        })
    }

    struct FakeLogger;
    impl LoggerPort for FakeLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    // Ruby: test "returns disabled result when agrr is not enabled"
    #[test]
    fn returns_disabled_result_when_agrr_is_not_enabled() {
        let crop = TestCrop {
            id: 1,
            name: "トマト".into(),
            variety: Some("general".into()),
        };
        let crop_gateway = StubCropGateway { rows: vec![] };
        let optimization_gateway = StubOptimizationGateway {
            outcome: StubOptimizeOutcome::Ok(json!({})),
            captured_requirement: Arc::new(Mutex::new(None)),
        };
        let clock = FakeClock {
            today_val: date!(2026-06-15),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &crop,
            weather_rows(),
            &crop_gateway,
            &StubBuilder,
            &optimization_gateway,
            &clock,
            None::<&FakeLogger>,
            false,
        );
        let result = interactor.call();
        assert!(!result.eligible);
        assert_eq!(
            result.reason_parts.get("error_key"),
            Some(&json!("disabled"))
        );
    }

    // Ruby: test "evaluation_range intersects last-june through next-june with weather dates"
    #[test]
    fn evaluation_range_intersects_weather_dates() {
        let crop = TestCrop {
            id: 1,
            name: "トマト".into(),
            variety: None,
        };
        let crop_gateway = StubCropGateway { rows: vec![] };
        let optimization_gateway = StubOptimizationGateway {
            outcome: StubOptimizeOutcome::Ok(json!({})),
            captured_requirement: Arc::new(Mutex::new(None)),
        };
        let clock = FakeClock {
            today_val: date!(2026-06-15),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &crop,
            weather_rows(),
            &crop_gateway,
            &StubBuilder,
            &optimization_gateway,
            &clock,
            None::<&FakeLogger>,
            true,
        );
        let range = interactor.evaluation_range().unwrap();
        assert_eq!(range.0, date!(2026-05-01));
        assert_eq!(range.1, date!(2026-05-03));
    }

    // Ruby: test "scales crop requirement via EntryScheduleStageGddScaler before optimize_period"
    #[test]
    fn scales_crop_requirement_before_optimize_period() {
        let crop = TestCrop {
            id: 1,
            name: "トマト".into(),
            variety: None,
        };
        let captured = Arc::new(Mutex::new(None));
        let crop_gateway = StubCropGateway { rows: vec![] };
        let optimization_gateway = StubOptimizationGateway {
            outcome: StubOptimizeOutcome::Ok(json!({
                "start_date": "2026-05-01",
                "completion_date": "2026-05-10",
                "days": 10,
                "gdd": 100.0,
                "cost": 1.0
            })),
            captured_requirement: Arc::clone(&captured),
        };
        let clock = FakeClock {
            today_val: date!(2026-06-15),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &crop,
            weather_rows(),
            &crop_gateway,
            &StubBuilder,
            &optimization_gateway,
            &clock,
            None::<&FakeLogger>,
            true,
        );
        let result = interactor.call();
        assert!(result.eligible);
        assert_eq!(
            result.reason_parts.get("source").and_then(|v| v.as_str()),
            Some("agrr_optimize_period")
        );
        let req = captured.lock().unwrap().clone().unwrap();
        let total: f64 = req["stage_requirements"]
            .as_array()
            .unwrap()
            .iter()
            .filter_map(|s| s["thermal"]["required_gdd"].as_f64())
            .sum();
        assert!(total <= 2000.01);
    }

    // Ruby: test "maps EntryScheduleOptimizationError to failed result"
    #[test]
    fn maps_entry_schedule_optimization_error_to_failed_result() {
        let crop = TestCrop {
            id: 1,
            name: "トマト".into(),
            variety: None,
        };
        let crop_gateway = StubCropGateway { rows: vec![] };
        let optimization_gateway = StubOptimizationGateway {
            outcome: StubOptimizeOutcome::Err(EntryScheduleOptimizationError::new(
                "daemon_unavailable",
                "down",
            )),
            captured_requirement: Arc::new(Mutex::new(None)),
        };
        let clock = FakeClock {
            today_val: date!(2026-06-15),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &crop,
            weather_rows(),
            &crop_gateway,
            &StubBuilder,
            &optimization_gateway,
            &clock,
            None::<&FakeLogger>,
            true,
        );
        let result = interactor.call();
        assert!(!result.eligible);
        assert_eq!(
            result.reason_parts.get("error_key").and_then(|v| v.as_str()),
            Some("daemon_unavailable")
        );
    }
}
