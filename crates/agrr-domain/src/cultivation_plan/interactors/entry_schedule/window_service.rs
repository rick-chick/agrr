//! Ruby: `Domain::CultivationPlan::Interactors::EntrySchedule::WindowService`

use std::collections::BTreeMap;

use serde_json::Value;
use time::Date;

use super::crop_stage_snapshot::CropStageSnapshot;
use super::stage_role_resolver::StageRoleResolver;
use super::temperature_requirement_snapshot::TemperatureRequirementSnapshot;
use crate::cultivation_plan::helpers::parse_iso_date;

struct DailyRow {
    date: Date,
    t_min: f64,
    t_max: f64,
    t_mean: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct DateRange {
    pub start_date: Date,
    pub end_date: Date,
}

#[derive(Debug, Clone, PartialEq)]
pub struct WindowServiceResult {
    pub eligible: bool,
    pub sowing_windows: Vec<DateRange>,
    pub transplant_windows: Vec<DateRange>,
    pub reason_parts: BTreeMap<String, Value>,
    pub sowing_stage_id: Option<i64>,
    pub transplant_stage_id: Option<i64>,
    pub weather_end_date: Option<Date>,
}

pub struct WindowService {
    ordered_crop_stages: Vec<CropStageSnapshot>,
    weather_payload: Value,
}

impl WindowService {
    pub fn call(ordered_crop_stages: Vec<CropStageSnapshot>, weather_payload: Value) -> WindowServiceResult {
        Self {
            ordered_crop_stages,
            weather_payload,
        }
        .run()
    }

    fn run(self) -> WindowServiceResult {
        let sow_st = StageRoleResolver::sowing_stage(&self.ordered_crop_stages);
        let tr_st = StageRoleResolver::transplant_stage(&self.ordered_crop_stages);

        let (sow_tr, sow_temp, tr_temp) = match (sow_st.as_ref(), tr_st.as_ref()) {
            (Some(s), Some(t)) => (
                Some((s, t)),
                s.temperature_requirement.as_ref(),
                t.temperature_requirement.as_ref(),
            ),
            _ => (None, None, None),
        };

        if sow_tr.is_none() || sow_temp.is_none() || tr_temp.is_none() {
            return Self::empty_result("missing_stages_or_temperature");
        }

        let daily = Self::extract_daily_series(&self.weather_payload);
        if daily.is_empty() {
            return Self::empty_result("no_weather_series");
        }

        let sow_st = sow_st.expect("stages checked");
        let tr_st = tr_st.expect("stages checked");
        let sow_temp = sow_st.temperature_requirement.as_ref().expect("temp checked");
        let tr_temp = tr_st.temperature_requirement.as_ref().expect("temp checked");

        let sow_ok_dates: Vec<Date> = daily
            .iter()
            .filter(|row| Self::day_viable(row, sow_temp))
            .map(|row| row.date)
            .collect();
        let tr_ok_dates: Vec<Date> = daily
            .iter()
            .filter(|row| Self::day_viable(row, tr_temp))
            .map(|row| row.date)
            .collect();

        let weather_end = daily.iter().map(|r| r.date).max();

        let mut reason_parts = BTreeMap::new();
        reason_parts.insert("rule".into(), Value::String("temperature_thresholds".into()));
        reason_parts.insert(
            "sowing_stage_name".into(),
            Value::String(sow_st.name.clone()),
        );
        reason_parts.insert(
            "transplant_stage_name".into(),
            Value::String(tr_st.name.clone()),
        );
        reason_parts.insert(
            "days_evaluated".into(),
            Value::Number(daily.len().into()),
        );

        WindowServiceResult {
            eligible: true,
            sowing_windows: Self::merge_consecutive_dates(sow_ok_dates),
            transplant_windows: Self::merge_consecutive_dates(tr_ok_dates),
            reason_parts,
            sowing_stage_id: Some(sow_st.id),
            transplant_stage_id: Some(tr_st.id),
            weather_end_date: weather_end,
        }
    }

    fn empty_result(reason: &str) -> WindowServiceResult {
        let mut reason_parts = BTreeMap::new();
        reason_parts.insert("error".into(), Value::String(reason.into()));
        WindowServiceResult {
            eligible: false,
            sowing_windows: vec![],
            transplant_windows: vec![],
            reason_parts,
            sowing_stage_id: None,
            transplant_stage_id: None,
            weather_end_date: None,
        }
    }

    fn extract_daily_series(payload: &Value) -> Vec<DailyRow> {
        let data = payload
            .get("data")
            .or_else(|| payload.get("data"))
            .and_then(|v| v.as_array());
        let Some(data) = data else {
            return vec![];
        };

        let mut rows = Vec::new();
        for datum in data {
            let Some(datum) = datum.as_object() else {
                continue;
            };
            let Some(date) = Self::parse_day(datum) else {
                continue;
            };
            let t_max = Self::float_val(datum.get("temperature_2m_max"));
            let t_min = Self::float_val(datum.get("temperature_2m_min"));
            let mut t_mean = Self::float_val(datum.get("temperature_2m_mean"));
            if t_mean.is_none() {
                if let (Some(max), Some(min)) = (t_max, t_min) {
                    t_mean = Some((max + min) / 2.0);
                }
            }
            let (Some(t_max), Some(t_min), Some(t_mean)) = (t_max, t_min, t_mean) else {
                continue;
            };
            rows.push(DailyRow {
                date,
                t_min,
                t_max,
                t_mean,
            });
        }
        rows.sort_by_key(|r| r.date);
        rows.dedup_by_key(|r| r.date);
        rows
    }

    fn parse_day(datum: &serde_json::Map<String, Value>) -> Option<Date> {
        let raw = datum
            .get("time")
            .or_else(|| datum.get("date"))
            .and_then(|v| v.as_str())?;
        if raw.trim().is_empty() {
            return None;
        }
        parse_iso_date(raw)
    }

    fn float_val(v: Option<&Value>) -> Option<f64> {
        match v {
            Some(Value::Number(n)) => n.as_f64(),
            Some(Value::String(s)) => s.parse().ok(),
            _ => None,
        }
    }

    fn day_viable(row: &DailyRow, temp_req: &TemperatureRequirementSnapshot) -> bool {
        if let Some(frost) = temp_req.frost_threshold {
            if row.t_min < frost {
                return false;
            }
        }
        if let (Some(min), Some(max)) = (temp_req.optimal_min, temp_req.optimal_max) {
            return row.t_mean >= min && row.t_mean <= max;
        }
        if let Some(min) = temp_req.optimal_min {
            return row.t_mean >= min;
        }
        if let Some(base) = temp_req.base_temperature {
            return row.t_min >= base;
        }
        false
    }

    fn merge_consecutive_dates(dates: Vec<Date>) -> Vec<DateRange> {
        if dates.is_empty() {
            return vec![];
        }
        let mut sorted = dates;
        sorted.sort();
        sorted.dedup();

        let mut ranges = Vec::new();
        let mut range_start = sorted[0];
        let mut prev = sorted[0];

        for d in sorted.into_iter().skip(1) {
            if d == prev + time::Duration::days(1) {
                prev = d;
            } else {
                ranges.push(DateRange {
                    start_date: range_start,
                    end_date: prev,
                });
                range_start = d;
                prev = d;
            }
        }
        ranges.push(DateRange {
            start_date: range_start,
            end_date: prev,
        });
        ranges
    }
}

#[cfg(test)]
mod interactors_entry_schedule_window_service_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_entry_schedule_window_service_test.rs"));
}
