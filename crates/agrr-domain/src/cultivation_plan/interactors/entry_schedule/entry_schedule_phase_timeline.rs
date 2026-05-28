//! Ruby: `Domain::CultivationPlan::Interactors::EntrySchedule::EntrySchedulePhaseTimeline`

use std::collections::BTreeMap;

use serde_json::Value;
use time::Date;

use super::window_service::{DateRange, WindowServiceResult};
use crate::shared::ports::{ClockPort, TranslatorPort};

#[derive(Debug, Clone, PartialEq)]
pub struct PhaseSegment {
    pub phase_key: String,
    pub label: String,
    pub start_date: Option<String>,
    pub end_date: Option<String>,
    pub empty_reason: Option<String>,
}

pub struct EntrySchedulePhaseTimeline<'a, T> {
    translator: &'a T,
    clock: &'a dyn ClockPort,
}

impl<'a, T: TranslatorPort> EntrySchedulePhaseTimeline<'a, T> {
    pub fn new(translator: &'a T, clock: &'a dyn ClockPort) -> Self {
        Self { translator, clock }
    }

    pub fn phase_segments(&self, _crop: &Value, result: &WindowServiceResult) -> Vec<PhaseSegment> {
        let src = result
            .reason_parts
            .get("source")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        if src == "agrr_optimize_period" {
            return self.agrr_ratio_phase_segments(result);
        }

        let weather_end = result.weather_end_date;
        let sow_first = result.sowing_windows.first();
        let tr_first = result.transplant_windows.first();

        vec![
            self.segment_sowing(sow_first, weather_end, result.eligible),
            self.segment_nursery(sow_first, tr_first, weather_end, result.eligible),
            self.segment_transplant(tr_first, weather_end, result.eligible),
            self.segment_harvest(tr_first, weather_end, result.eligible),
        ]
    }

    fn t(&self, key: &str) -> String {
        self.translator.t(key, &Default::default())
    }

    fn phase_base(&self, key: &str) -> PhaseSegment {
        PhaseSegment {
            phase_key: key.to_string(),
            label: self.t(&format!("api.entry_schedule.phase.label.{key}")),
            start_date: None,
            end_date: None,
            empty_reason: None,
        }
    }

    fn segment_sowing(
        &self,
        sow_first: Option<&DateRange>,
        _weather_end: Option<Date>,
        eligible: bool,
    ) -> PhaseSegment {
        let mut h = self.phase_base("sowing");
        if !eligible {
            h.empty_reason = Some(self.t("api.entry_schedule.phase.empty.ineligible"));
            return h;
        }
        let Some(sow) = sow_first else {
            h.empty_reason = Some(self.t("api.entry_schedule.phase.empty.no_sowing_window"));
            return h;
        };
        h.start_date = Some(sow.start_date.to_string());
        h.end_date = Some(sow.end_date.to_string());
        h
    }

    fn segment_nursery(
        &self,
        sow_first: Option<&DateRange>,
        tr_first: Option<&DateRange>,
        _weather_end: Option<Date>,
        eligible: bool,
    ) -> PhaseSegment {
        let mut h = self.phase_base("nursery");
        if !eligible {
            h.empty_reason = Some(self.t("api.entry_schedule.phase.empty.ineligible"));
            return h;
        }
        let (Some(sow), Some(tr)) = (sow_first, tr_first) else {
            h.empty_reason = Some(self.t("api.entry_schedule.phase.empty.nursery_gap"));
            return h;
        };
        let start_d = sow.end_date + time::Duration::days(1);
        let end_d = tr.start_date - time::Duration::days(1);
        if end_d < start_d {
            h.empty_reason = Some(self.t("api.entry_schedule.phase.empty.nursery_gap"));
            return h;
        }
        h.start_date = Some(start_d.to_string());
        h.end_date = Some(end_d.to_string());
        h
    }

    fn segment_transplant(
        &self,
        tr_first: Option<&DateRange>,
        _weather_end: Option<Date>,
        eligible: bool,
    ) -> PhaseSegment {
        let mut h = self.phase_base("transplant");
        if !eligible {
            h.empty_reason = Some(self.t("api.entry_schedule.phase.empty.ineligible"));
            return h;
        }
        let Some(tr) = tr_first else {
            h.empty_reason = Some(self.t("api.entry_schedule.phase.empty.no_transplant_window"));
            return h;
        };
        h.start_date = Some(tr.start_date.to_string());
        h.end_date = Some(tr.end_date.to_string());
        h
    }

    fn segment_harvest(
        &self,
        tr_first: Option<&DateRange>,
        weather_end: Option<Date>,
        eligible: bool,
    ) -> PhaseSegment {
        let mut h = self.phase_base("harvest");
        if !eligible {
            h.empty_reason = Some(self.t("api.entry_schedule.phase.empty.ineligible"));
            return h;
        }
        let Some(tr) = tr_first else {
            h.empty_reason = Some(self.t("api.entry_schedule.phase.empty.no_transplant_window"));
            return h;
        };
        let Some(weather_end) = weather_end else {
            h.empty_reason = Some(self.t("api.entry_schedule.phase.empty.no_weather_end"));
            return h;
        };
        let start_d = tr.end_date + time::Duration::days(1);
        let end_d = weather_end.min(tr.end_date + time::Duration::days(120));
        let end_d = if end_d < start_d { start_d } else { end_d };
        h.start_date = Some(start_d.to_string());
        h.end_date = Some(end_d.to_string());
        h
    }

    fn agrr_ratio_phase_segments(&self, result: &WindowServiceResult) -> Vec<PhaseSegment> {
        let w = match result.sowing_windows.first() {
            Some(w) if result.eligible => w,
            _ => {
                return ["sowing", "nursery", "transplant", "harvest"]
                    .into_iter()
                    .map(|k| {
                        let mut h = self.phase_base(k);
                        h.empty_reason = Some(self.t("api.entry_schedule.phase.empty.ineligible"));
                        h
                    })
                    .collect();
            }
        };
        let s0 = w.start_date;
        let e0 = w.end_date;
        let weather_end = result.weather_end_date;
        vec![
            self.segment_from_quarter("sowing", s0, e0, 0),
            self.segment_from_quarter("nursery", s0, e0, 1),
            self.segment_from_quarter("transplant", s0, e0, 2),
            self.segment_harvest_from_quarter(s0, e0, weather_end, 3),
        ]
    }

    fn segment_from_quarter(&self, phase_key: &str, range_start: Date, range_end: Date, quarter_index: i32) -> PhaseSegment {
        let mut h = self.phase_base(phase_key);
        let (a, b) = Self::quarter_date_range(range_start, range_end, quarter_index);
        h.start_date = Some(a.to_string());
        h.end_date = Some(b.to_string());
        h
    }

    fn segment_harvest_from_quarter(
        &self,
        s0: Date,
        e0: Date,
        weather_end: Option<Date>,
        quarter_index: i32,
    ) -> PhaseSegment {
        let mut h = self.phase_base("harvest");
        let Some(weather_end) = weather_end else {
            h.empty_reason = Some(self.t("api.entry_schedule.phase.empty.no_weather_end"));
            return h;
        };
        let (a, b) = Self::quarter_date_range(s0, e0, quarter_index);
        let end_d = b.min(weather_end);
        let end_d = if end_d < a { a } else { end_d };
        h.start_date = Some(a.to_string());
        h.end_date = Some(end_d.to_string());
        h
    }

    fn quarter_date_range(range_start: Date, range_end: Date, quarter_index: i32) -> (Date, Date) {
        let total_days = (range_end - range_start).whole_days() + 1;
        let f0 = quarter_index as f64 / 4.0;
        let f1 = (quarter_index + 1) as f64 / 4.0;
        let start_off = (total_days as f64 * f0).floor() as i64;
        let end_off = (total_days as f64 * f1).ceil() as i64 - 1;
        let mut a = range_start + time::Duration::days(start_off);
        let mut b = range_start + time::Duration::days(end_off);
        if b > range_end {
            b = range_end;
        }
        if b < a {
            b = a;
        }
        (a, b)
    }

    pub fn sort_meta(&self, result: &WindowServiceResult) -> BTreeMap<String, Value> {
        let sow_first = result.sowing_windows.first();
        let mut meta = BTreeMap::new();
        meta.insert("eligible".into(), Value::Bool(result.eligible));
        meta.insert(
            "sowing_proximity_days".into(),
            Value::Number(self.sowing_proximity_days(sow_first, result.eligible).into()),
        );
        meta.insert(
            "sowing_window_width_days".into(),
            Value::Number(self.window_width_days(sow_first).into()),
        );
        meta
    }

    fn sowing_proximity_days(&self, sow_first: Option<&DateRange>, eligible: bool) -> i64 {
        if !eligible {
            return 999_999;
        }
        let Some(sow) = sow_first else {
            return 999_999;
        };
        let today = self.clock.today();
        if sow.start_date <= today && today <= sow.end_date {
            return 0;
        }
        if today < sow.start_date {
            return (sow.start_date - today).whole_days();
        }
        (today - sow.end_date).whole_days() + 1000
    }

    fn window_width_days(&self, sow_first: Option<&DateRange>) -> i64 {
        let Some(sow) = sow_first else {
            return 999_999;
        };
        (sow.end_date - sow.start_date).whole_days() + 1
    }
}
