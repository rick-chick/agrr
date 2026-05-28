//! Ruby: `Domain::PublicPlan::Mappers::EntryScheduleCropMapper`

use std::collections::BTreeMap;

use serde_json::{json, Value};
use time::Date;

use crate::shared::ports::{ClockPort, TranslatorPort, TranslateOptions};

/// Ruby: `WindowService::Result`
#[derive(Debug, Clone, PartialEq)]
pub struct EntryScheduleWindowResult {
    pub eligible: bool,
    pub sowing_windows: Vec<DateWindow>,
    pub transplant_windows: Vec<DateWindow>,
    pub reason_parts: BTreeMap<String, Value>,
    pub sowing_stage_id: Option<i64>,
    pub transplant_stage_id: Option<i64>,
    pub weather_end_date: Option<Date>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DateWindow {
    pub start_date: Date,
    pub end_date: Date,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CropStageRow {
    pub id: i64,
    pub name: String,
    pub order: i32,
}

/// Minimal crop for entry schedule fragments.
pub trait EntryScheduleCropLike {
    fn id(&self) -> i64;
    fn name(&self) -> &str;
}

/// Farm with weather location for prediction meta.
pub trait EntryScheduleFarmLike {
    fn weather_location_id(&self) -> Option<i64>;
}

/// Ruby: `EntryScheduleCropMapper.prediction_meta`
pub fn prediction_meta(
    farm: &dyn EntryScheduleFarmLike,
    payload_hash: &BTreeMap<String, Value>,
    chart_calendar_year: i32,
) -> BTreeMap<String, Value> {
    let mut out = BTreeMap::new();
    if let Some(v) = payload_hash
        .get("generated_at")
        .or_else(|| payload_hash.get("predicted_at"))
    {
        out.insert("generated_at".into(), v.clone());
    }
    if let Some(v) = payload_hash.get("prediction_start_date") {
        out.insert("prediction_start_date".into(), v.clone());
    }
    if let Some(v) = payload_hash
        .get("prediction_end_date")
        .or_else(|| payload_hash.get("target_end_date"))
    {
        out.insert("prediction_end_date".into(), v.clone());
    }
    if let Some(id) = farm.weather_location_id() {
        out.insert("weather_location_id".into(), json!(id));
    }
    out.insert("chart_calendar_year".into(), json!(chart_calendar_year));
    out
}

/// Ruby: `EntryScheduleCropMapper.crop_detail` (simplified timeline for domain parity tests).
pub fn crop_detail(
    crop: &dyn EntryScheduleCropLike,
    result: &EntryScheduleWindowResult,
    translator: &dyn TranslatorPort,
    crop_stages: &[CropStageRow],
    _clock: &dyn ClockPort,
) -> BTreeMap<String, Value> {
    let mut item = crop_list_item(crop, result, translator);
    item.insert(
        "sowing_windows".into(),
        serialize_windows(&result.sowing_windows),
    );
    item.insert(
        "transplant_windows".into(),
        serialize_windows(&result.transplant_windows),
    );
    item.insert("reason_parts".into(), json!(result.reason_parts));
    item.insert("sowing_stage_id".into(), json!(result.sowing_stage_id));
    item.insert(
        "transplant_stage_id".into(),
        json!(result.transplant_stage_id),
    );
    item.insert(
        "crop_stages".into(),
        json!(
            crop_stages
                .iter()
                .map(|s| json!({ "id": s.id, "name": s.name, "order": s.order }))
                .collect::<Vec<_>>()
        ),
    );
    item.insert(
        "entry_disclaimer".into(),
        json!(translator.t("api.entry_schedule.disclaimer.short", &empty_options())),
    );
    item.insert(
        "next_task".into(),
        json!({
            "available": false,
            "code": "catalog",
            "summary": null
        }),
    );
    item
}

fn crop_list_item(
    crop: &dyn EntryScheduleCropLike,
    result: &EntryScheduleWindowResult,
    translator: &dyn TranslatorPort,
) -> BTreeMap<String, Value> {
    let sow_first = result.sowing_windows.first();
    let tr_first = result.transplant_windows.first();
    let mut item = BTreeMap::new();
    item.insert("id".into(), json!(crop.id()));
    item.insert("name".into(), json!(crop.name()));
    item.insert("eligible".into(), json!(result.eligible));
    item.insert(
        "sowing_summary".into(),
        window_summary(sow_first),
    );
    item.insert(
        "transplant_summary".into(),
        window_summary(tr_first),
    );
    item.insert(
        "reason_summary".into(),
        json!(reason_summary_text(result, translator)),
    );
    item.insert(
        "labels".into(),
        json!({
            "sowing": translator.t("api.entry_schedule.label.sowing", &empty_options()),
            "transplanting": translator.t("api.entry_schedule.label.transplanting", &empty_options()),
        }),
    );
    item.insert("schedule_flow_summary".into(), json!(null));
    item.insert("schedule_flow_detail".into(), Value::Null);
    item.insert("phase_segments".into(), json!([]));
    item.insert("rough_timeline".into(), json!([]));
    item.insert(
        "sort_meta".into(),
        json!({
            "eligible": result.eligible,
            "sowing_proximity_days": 0,
            "sowing_window_width_days": 0,
        }),
    );
    item
}

fn window_summary(window: Option<&DateWindow>) -> Value {
    window.map_or(Value::Null, |w| {
        json!({
            "start_date": w.start_date.to_string(),
            "end_date": w.end_date.to_string(),
        })
    })
}

fn serialize_windows(windows: &[DateWindow]) -> Value {
    json!(
        windows
            .iter()
            .map(|w| json!({
                "start_date": w.start_date.to_string(),
                "end_date": w.end_date.to_string(),
            }))
            .collect::<Vec<_>>()
    )
}

fn reason_summary_text(result: &EntryScheduleWindowResult, translator: &dyn TranslatorPort) -> String {
    if let Some(Value::String(err)) = result.reason_parts.get("error") {
        return err.clone();
    }
    let src = result
        .reason_parts
        .get("source")
        .and_then(|v| v.as_str())
        .unwrap_or("");
    if src == "agrr_optimize_period" {
        return translator.t("api.entry_schedule.reason.agrr", &empty_options());
    }
    if src == "agrr_failed" {
        return translator.t(
            "api.entry_schedule.reason.agrr_failed.generic",
            &empty_options(),
        );
    }
    translator.t("api.entry_schedule.reason.list", &empty_options())
}

fn empty_options() -> TranslateOptions {
    BTreeMap::new()
}
