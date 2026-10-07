//! Types shared by entry-schedule optimization results (`WindowService` threshold scan removed).

use std::collections::BTreeMap;

use serde_json::Value;
use time::Date;

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
