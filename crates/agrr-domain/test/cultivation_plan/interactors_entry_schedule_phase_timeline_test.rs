// Tests for `interactors/entry_schedule/entry_schedule_phase_timeline.rs`.

use std::collections::BTreeMap;

use serde_json::json;
use time::macros::date;

use crate::cultivation_plan::interactors::entry_schedule::{
    DateRange, EntrySchedulePhaseTimeline, WindowServiceResult,
};
use crate::shared::ports::{ClockPort, TranslatorPort, TranslateOptions};

struct KeyTranslator;

impl TranslatorPort for KeyTranslator {
    fn translate(&self, key: &str, _options: &TranslateOptions) -> String {
        key.to_string()
    }

    fn localize(
        &self,
        _date: time::Date,
        _format: Option<&str>,
        _options: &TranslateOptions,
    ) -> String {
        String::new()
    }
}

struct FixedClock {
    today: time::Date,
}

impl ClockPort for FixedClock {
    fn today(&self) -> time::Date {
        self.today
    }

    fn now(&self) -> time::OffsetDateTime {
        time::OffsetDateTime::UNIX_EPOCH
    }
}

fn window_result(
    eligible: bool,
    source: &str,
    sowing_windows: Vec<DateRange>,
    transplant_windows: Vec<DateRange>,
    weather_end_date: Option<time::Date>,
) -> WindowServiceResult {
    let mut reason_parts = BTreeMap::new();
    reason_parts.insert("source".into(), json!(source));
    WindowServiceResult {
        eligible,
        sowing_windows,
        transplant_windows,
        reason_parts,
        sowing_stage_id: Some(1),
        transplant_stage_id: Some(2),
        weather_end_date,
    }
}

fn eligible_window_result(source: &str) -> WindowServiceResult {
    window_result(
        true,
        source,
        vec![DateRange {
            start_date: date!(2026-03-01),
            end_date: date!(2026-04-15),
        }],
        vec![DateRange {
            start_date: date!(2026-04-20),
            end_date: date!(2026-05-10),
        }],
        Some(date!(2026-12-31)),
    )
}

#[test]
fn phase_segments_builds_sowing_nursery_transplant_harvest_for_window_service() {
    let translator = KeyTranslator;
    let clock = FixedClock {
        today: date!(2026-06-15),
    };
    let timeline = EntrySchedulePhaseTimeline::new(&translator, &clock);
    let result = eligible_window_result("window_service");

    let segments = timeline.phase_segments(&json!({}), &result);

    assert_eq!(segments.len(), 4);
    assert_eq!(segments[0].phase_key, "sowing");
    assert_eq!(segments[0].start_date.as_deref(), Some("2026-03-01"));
    assert_eq!(segments[0].end_date.as_deref(), Some("2026-04-15"));
    assert!(segments[0].empty_reason.is_none());

    assert_eq!(segments[1].phase_key, "nursery");
    assert_eq!(segments[1].start_date.as_deref(), Some("2026-04-16"));
    assert_eq!(segments[1].end_date.as_deref(), Some("2026-04-19"));

    assert_eq!(segments[2].phase_key, "transplant");
    assert_eq!(segments[2].start_date.as_deref(), Some("2026-04-20"));
    assert_eq!(segments[2].end_date.as_deref(), Some("2026-05-10"));

    assert_eq!(segments[3].phase_key, "harvest");
    assert_eq!(segments[3].start_date.as_deref(), Some("2026-05-11"));
    assert_eq!(segments[3].end_date.as_deref(), Some("2026-09-07"));
}

#[test]
fn phase_segments_marks_all_phases_ineligible_when_crop_is_not_eligible() {
    let translator = KeyTranslator;
    let clock = FixedClock {
        today: date!(2026-06-15),
    };
    let timeline = EntrySchedulePhaseTimeline::new(&translator, &clock);
    let result = window_result(false, "window_service", vec![], vec![], None);

    let segments = timeline.phase_segments(&json!({}), &result);

    assert_eq!(segments.len(), 4);
    for segment in &segments {
        assert_eq!(
            segment.empty_reason.as_deref(),
            Some("api.entry_schedule.phase.empty.ineligible")
        );
        assert!(segment.start_date.is_none());
        assert!(segment.end_date.is_none());
    }
}

#[test]
fn phase_segments_reports_missing_weather_end_for_harvest_phase() {
    let translator = KeyTranslator;
    let clock = FixedClock {
        today: date!(2026-06-15),
    };
    let timeline = EntrySchedulePhaseTimeline::new(&translator, &clock);
    let result = window_result(
        true,
        "window_service",
        vec![DateRange {
            start_date: date!(2026-03-01),
            end_date: date!(2026-04-15),
        }],
        vec![DateRange {
            start_date: date!(2026-04-20),
            end_date: date!(2026-05-10),
        }],
        None,
    );

    let segments = timeline.phase_segments(&json!({}), &result);
    let harvest = &segments[3];

    assert_eq!(harvest.phase_key, "harvest");
    assert_eq!(
        harvest.empty_reason.as_deref(),
        Some("api.entry_schedule.phase.empty.no_weather_end")
    );
    assert!(harvest.start_date.is_none());
    assert!(harvest.end_date.is_none());
}

#[test]
fn phase_segments_reports_nursery_gap_when_transplant_window_is_missing() {
    let translator = KeyTranslator;
    let clock = FixedClock {
        today: date!(2026-06-15),
    };
    let timeline = EntrySchedulePhaseTimeline::new(&translator, &clock);
    let result = window_result(
        true,
        "window_service",
        vec![DateRange {
            start_date: date!(2026-03-01),
            end_date: date!(2026-04-15),
        }],
        vec![],
        Some(date!(2026-12-31)),
    );

    let segments = timeline.phase_segments(&json!({}), &result);
    let nursery = &segments[1];

    assert_eq!(nursery.phase_key, "nursery");
    assert_eq!(
        nursery.empty_reason.as_deref(),
        Some("api.entry_schedule.phase.empty.nursery_gap")
    );
}

#[test]
fn phase_segments_splits_agrr_optimize_period_into_quarter_segments() {
    let translator = KeyTranslator;
    let clock = FixedClock {
        today: date!(2026-06-15),
    };
    let timeline = EntrySchedulePhaseTimeline::new(&translator, &clock);
    let result = eligible_window_result("agrr_optimize_period");

    let segments = timeline.phase_segments(&json!({}), &result);

    assert_eq!(segments.len(), 4);
    assert_eq!(segments[0].phase_key, "sowing");
    assert_eq!(segments[0].start_date.as_deref(), Some("2026-03-01"));
    assert_eq!(segments[0].end_date.as_deref(), Some("2026-03-12"));
    assert_eq!(segments[3].phase_key, "harvest");
    assert!(segments[3].end_date.as_deref().unwrap() <= "2026-12-31");
}

#[test]
fn phase_segments_marks_agrr_optimize_period_ineligible_without_primary_window() {
    let translator = KeyTranslator;
    let clock = FixedClock {
        today: date!(2026-06-15),
    };
    let timeline = EntrySchedulePhaseTimeline::new(&translator, &clock);
    let result = window_result(false, "agrr_optimize_period", vec![], vec![], None);

    let segments = timeline.phase_segments(&json!({}), &result);

    assert_eq!(segments.len(), 4);
    for segment in &segments {
        assert_eq!(
            segment.empty_reason.as_deref(),
            Some("api.entry_schedule.phase.empty.ineligible")
        );
    }
}

#[test]
fn sort_meta_returns_zero_proximity_when_today_is_inside_sowing_window() {
    let translator = KeyTranslator;
    let clock = FixedClock {
        today: date!(2026-04-01),
    };
    let timeline = EntrySchedulePhaseTimeline::new(&translator, &clock);
    let result = eligible_window_result("window_service");

    let meta = timeline.sort_meta(&result);

    assert_eq!(meta.get("eligible").and_then(|v| v.as_bool()), Some(true));
    assert_eq!(
        meta.get("sowing_proximity_days").and_then(|v| v.as_i64()),
        Some(0)
    );
    assert_eq!(
        meta.get("sowing_window_width_days").and_then(|v| v.as_i64()),
        Some(46)
    );
}

#[test]
fn sort_meta_returns_days_until_start_when_today_is_before_sowing_window() {
    let translator = KeyTranslator;
    let clock = FixedClock {
        today: date!(2026-02-15),
    };
    let timeline = EntrySchedulePhaseTimeline::new(&translator, &clock);
    let result = eligible_window_result("window_service");

    let meta = timeline.sort_meta(&result);

    assert_eq!(
        meta.get("sowing_proximity_days").and_then(|v| v.as_i64()),
        Some(14)
    );
}

#[test]
fn sort_meta_penalizes_past_sowing_windows_for_list_ordering() {
    let translator = KeyTranslator;
    let clock = FixedClock {
        today: date!(2026-06-15),
    };
    let timeline = EntrySchedulePhaseTimeline::new(&translator, &clock);
    let result = eligible_window_result("window_service");

    let meta = timeline.sort_meta(&result);

    assert_eq!(
        meta.get("sowing_proximity_days").and_then(|v| v.as_i64()),
        Some(1061)
    );
}
