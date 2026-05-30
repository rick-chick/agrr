//! Ruby: `Domain::CultivationPlan::Interactors::EntryScheduleOptimizeInteractor`

use std::collections::BTreeMap;

use serde_json::{json, Value};

use crate::cultivation_plan::calculators::entry_schedule_stage_gdd_scaler;
use crate::cultivation_plan::errors::EntryScheduleOptimizationError;
use crate::cultivation_plan::gateways::{
    EntryScheduleCropGateway, EntryScheduleOptimizationGateway,
};
use crate::cultivation_plan::interactors::entry_schedule::{
    stage_role_resolver::StageRoleResolver, DateRange, WindowServiceResult,
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
mod interactors_entry_schedule_optimize_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_entry_schedule_optimize_interactor_test.rs"));
}
