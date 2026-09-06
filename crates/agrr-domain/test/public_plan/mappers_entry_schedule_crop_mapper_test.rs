// Tests for `mappers/entry_schedule_crop_mapper.rs`.

use std::collections::BTreeMap;

use serde_json::json;
use time::macros::date;

use crate::public_plan::mappers::entry_schedule_crop_mapper::{
    crop_detail, prediction_meta, CropStageRow, DateWindow, EntryScheduleCropLike,
    EntryScheduleFarmLike, EntryScheduleWindowResult,
};
use crate::shared::ports::{ClockPort, TranslatorPort, TranslateOptions};

struct TestCrop {
    id: i64,
    name: &'static str,
}

impl EntryScheduleCropLike for TestCrop {
    fn id(&self) -> i64 {
        self.id
    }

    fn name(&self) -> &str {
        self.name
    }
}

struct TestFarm {
    weather_location_id: Option<i64>,
}

impl EntryScheduleFarmLike for TestFarm {
    fn weather_location_id(&self) -> Option<i64> {
        self.weather_location_id
    }
}

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
    extra_reason: Option<(&str, serde_json::Value)>,
) -> EntryScheduleWindowResult {
    let mut reason_parts = BTreeMap::new();
    reason_parts.insert("source".into(), json!(source));
    if let Some((key, value)) = extra_reason {
        reason_parts.insert(key.into(), value);
    }
    EntryScheduleWindowResult {
        eligible,
        sowing_windows: if eligible {
            vec![DateWindow {
                start_date: date!(2026-03-01),
                end_date: date!(2026-04-15),
            }]
        } else {
            vec![]
        },
        transplant_windows: if eligible {
            vec![DateWindow {
                start_date: date!(2026-04-20),
                end_date: date!(2026-05-10),
            }]
        } else {
            vec![]
        },
        reason_parts,
        sowing_stage_id: Some(1),
        transplant_stage_id: Some(2),
        weather_end_date: Some(date!(2026-12-31)),
    }
}

#[test]
fn prediction_meta_uses_generated_at_and_prediction_end_date_aliases() {
    let farm = TestFarm {
        weather_location_id: Some(99),
    };
    let payload = BTreeMap::from([
        ("predicted_at".into(), json!("2026-01-01T00:00:00Z")),
        ("target_end_date".into(), json!("2026-12-31")),
        ("prediction_start_date".into(), json!("2025-01-01")),
    ]);

    let meta = prediction_meta(&farm, &payload, 2026);

    assert_eq!(
        meta.get("generated_at").and_then(|v| v.as_str()),
        Some("2026-01-01T00:00:00Z")
    );
    assert_eq!(
        meta.get("prediction_end_date").and_then(|v| v.as_str()),
        Some("2026-12-31")
    );
    assert_eq!(
        meta.get("prediction_start_date").and_then(|v| v.as_str()),
        Some("2025-01-01")
    );
    assert_eq!(meta.get("weather_location_id").and_then(|v| v.as_i64()), Some(99));
    assert_eq!(meta.get("chart_calendar_year").and_then(|v| v.as_i64()), Some(2026));
}

#[test]
fn prediction_meta_omits_weather_location_id_when_farm_has_none() {
    let farm = TestFarm {
        weather_location_id: None,
    };
    let payload = BTreeMap::from([("generated_at".into(), json!("2026-01-01T00:00:00Z"))]);

    let meta = prediction_meta(&farm, &payload, 2026);

    assert!(meta.get("weather_location_id").is_none());
}

#[test]
fn crop_detail_reason_summary_uses_agrr_key_for_optimize_period_source() {
    let crop = TestCrop { id: 7, name: "Tomato" };
    let translator = KeyTranslator;
    let clock = FixedClock {
        today: date!(2026-06-15),
    };
    let result = window_result(true, "agrr_optimize_period", None);

    let detail = crop_detail(&crop, &result, &translator, &[], &clock);

    assert_eq!(
        detail.get("reason_summary").and_then(|v| v.as_str()),
        Some("api.entry_schedule.reason.agrr")
    );
}

#[test]
fn crop_detail_reason_summary_uses_agrr_failed_key_for_failed_source() {
    let crop = TestCrop { id: 7, name: "Tomato" };
    let translator = KeyTranslator;
    let clock = FixedClock {
        today: date!(2026-06-15),
    };
    let result = window_result(false, "agrr_failed", Some(("error_key", json!("execution_failed"))));

    let detail = crop_detail(&crop, &result, &translator, &[], &clock);

    assert_eq!(
        detail.get("reason_summary").and_then(|v| v.as_str()),
        Some("api.entry_schedule.reason.agrr_failed.generic")
    );
}

#[test]
fn crop_detail_reason_summary_returns_raw_error_string_when_present() {
    let crop = TestCrop { id: 7, name: "Tomato" };
    let translator = KeyTranslator;
    let clock = FixedClock {
        today: date!(2026-06-15),
    };
    let result = window_result(false, "legacy", Some(("error", json!("custom failure"))));

    let detail = crop_detail(&crop, &result, &translator, &[], &clock);

    assert_eq!(
        detail.get("reason_summary").and_then(|v| v.as_str()),
        Some("custom failure")
    );
}

#[test]
fn crop_detail_reason_summary_falls_back_to_list_key_for_other_sources() {
    let crop = TestCrop { id: 7, name: "Tomato" };
    let translator = KeyTranslator;
    let clock = FixedClock {
        today: date!(2026-06-15),
    };
    let result = window_result(true, "window_service", None);

    let detail = crop_detail(&crop, &result, &translator, &[], &clock);

    assert_eq!(
        detail.get("reason_summary").and_then(|v| v.as_str()),
        Some("api.entry_schedule.reason.list")
    );
}

#[test]
fn crop_detail_serializes_windows_and_crop_stages_for_eligible_crop() {
    let crop = TestCrop { id: 7, name: "Tomato" };
    let translator = KeyTranslator;
    let clock = FixedClock {
        today: date!(2026-06-15),
    };
    let result = window_result(true, "agrr_optimize_period", None);
    let stages = vec![
        CropStageRow {
            id: 1,
            name: "Sowing".into(),
            order: 1,
        },
        CropStageRow {
            id: 2,
            name: "Transplant".into(),
            order: 2,
        },
    ];

    let detail = crop_detail(&crop, &result, &translator, &stages, &clock);

    assert_eq!(detail.get("eligible").and_then(|v| v.as_bool()), Some(true));
    assert_eq!(
        detail
            .get("sowing_summary")
            .and_then(|v| v.get("start_date"))
            .and_then(|v| v.as_str()),
        Some("2026-03-01")
    );
    assert_eq!(
        detail
            .get("transplant_summary")
            .and_then(|v| v.get("end_date"))
            .and_then(|v| v.as_str()),
        Some("2026-05-10")
    );
    assert_eq!(
        detail.get("sowing_windows").and_then(|v| v.as_array()).map(|a| a.len()),
        Some(1)
    );
    assert_eq!(
        detail
            .get("crop_stages")
            .and_then(|v| v.as_array())
            .map(|a| a.len()),
        Some(2)
    );
}
