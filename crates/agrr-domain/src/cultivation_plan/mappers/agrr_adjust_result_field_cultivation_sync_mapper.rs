//! Ruby: `Adapters::CultivationPlan::Mappers::AgrrAdjustResultFieldCultivationSyncMapper`

use serde_json::Value;
use time::Date;

use crate::cultivation_plan::helpers::parse_iso_date;
use crate::field_cultivation::dtos::{
    FieldCultivationSyncAllocationInput, FieldCultivationSyncFieldScheduleInput,
    FieldCultivationSyncInput,
};

pub struct AgrrAdjustResultFieldCultivationSyncMapper;

impl AgrrAdjustResultFieldCultivationSyncMapper {
    pub fn to_sync_input(result: &Value) -> FieldCultivationSyncInput {
        let field_schedules = result
            .get("field_schedules")
            .or_else(|| result.pointer("/field_schedules"))
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .map(map_field_schedule)
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default();

        FieldCultivationSyncInput {
            field_schedules,
            optimization_summary: pick_string(result, "summary"),
            total_profit: pick_f64(result, "total_profit"),
            total_revenue: pick_f64(result, "total_revenue"),
            total_cost: pick_f64(result, "total_cost"),
            optimization_time: pick_f64(result, "optimization_time"),
            algorithm_used: pick_string(result, "algorithm_used"),
            is_optimal: pick_bool(result, "is_optimal"),
        }
    }
}

fn map_field_schedule(fs: &Value) -> FieldCultivationSyncFieldScheduleInput {
    let allocations = fs
        .get("allocations")
        .and_then(|v| v.as_array())
        .map(|arr| arr.iter().map(map_allocation).collect())
        .unwrap_or_default();

    FieldCultivationSyncFieldScheduleInput {
        field_id: pick_i64(fs, "field_id"),
        allocations,
    }
}

fn map_allocation(alloc: &Value) -> FieldCultivationSyncAllocationInput {
    let start = pick_string(alloc, "start_date")
        .and_then(|s| parse_iso_date(&s))
        .unwrap_or_else(|| Date::from_calendar_date(2026, time::Month::January, 1).unwrap());
    let completion = pick_string(alloc, "completion_date")
        .and_then(|s| parse_iso_date(&s))
        .unwrap_or(start);

    FieldCultivationSyncAllocationInput {
        allocation_id: pick_i64(alloc, "allocation_id"),
        external_allocation_id: pick_string(alloc, "id"),
        crop_id: pick_string(alloc, "crop_id").unwrap_or_default(),
        start_date: start,
        completion_date: completion,
        area_used: pick_f64(alloc, "area_used"),
        area: pick_f64(alloc, "area"),
        total_cost: pick_f64(alloc, "total_cost"),
        cost: pick_f64(alloc, "cost"),
        expected_revenue: pick_f64(alloc, "expected_revenue"),
        revenue: pick_f64(alloc, "revenue"),
        profit: pick_f64(alloc, "profit"),
        accumulated_gdd: pick_f64(alloc, "accumulated_gdd"),
    }
}

fn pick_string(h: &Value, key: &str) -> Option<String> {
    h.get(key)
        .or_else(|| h.get(key))
        .and_then(|v| v.as_str().map(str::to_string))
}

fn pick_i64(h: &Value, key: &str) -> Option<i64> {
    h.get(key).and_then(|v| v.as_i64())
}

fn pick_f64(h: &Value, key: &str) -> Option<f64> {
    h.get(key).and_then(|v| v.as_f64())
}

fn pick_bool(h: &Value, key: &str) -> Option<bool> {
    h.get(key).and_then(|v| v.as_bool())
}
