//! Ruby: `Domain::CultivationPlan::Mappers::PlanAllocationAdjustReadSnapshotParts`

use std::collections::BTreeMap;

use serde_json::{json, Value};

use crate::cultivation_plan::dtos::{
    PlanAllocationAdjustFieldCultivationAllocationSnapshot,
    PlanAllocationAdjustFieldCultivationSnapshot, PlanAllocationAdjustFieldSourceSnapshot,
    PlanAllocationAdjustPlanCropSnapshot, PlanAllocationAdjustPlanFieldSnapshot,
};
use crate::weather_data::dtos::WeatherLocation;

pub struct PlanAllocationAdjustReadSnapshotParts;

impl PlanAllocationAdjustReadSnapshotParts {
    pub fn effective_cultivation_days(
        stored_days: Option<i32>,
        start_date: time::Date,
        completion_date: time::Date,
    ) -> i32 {
        if let Some(days) = stored_days {
            return days;
        }
        (completion_date - start_date).whole_days() as i32 + 1
    }

    pub fn has_growth_stages(crop_stage_count: i32) -> bool {
        crop_stage_count > 0
    }

    fn effective_estimated_cost(estimated_cost: Option<f64>) -> f64 {
        estimated_cost.unwrap_or(0.0)
    }

    pub fn build_field_source_snapshots(
        plan_field_snapshots: &[PlanAllocationAdjustPlanFieldSnapshot],
        field_cultivation_snapshots: &[PlanAllocationAdjustFieldCultivationSnapshot],
    ) -> Vec<PlanAllocationAdjustFieldSourceSnapshot> {
        let mut cultivations_by_field: BTreeMap<i64, Vec<&PlanAllocationAdjustFieldCultivationSnapshot>> =
            BTreeMap::new();
        for fc in field_cultivation_snapshots {
            cultivations_by_field
                .entry(fc.field_id)
                .or_default()
                .push(fc);
        }

        plan_field_snapshots
            .iter()
            .map(|field| {
                let cultivations = cultivations_by_field
                    .get(&field.id)
                    .map(|rows| {
                        rows.iter()
                            .map(|fc| Self::field_cultivation_allocation_snapshot(fc))
                            .collect()
                    })
                    .unwrap_or_default();

                PlanAllocationAdjustFieldSourceSnapshot::new(
                    field.id,
                    field.name.clone(),
                    field.area,
                    cultivations,
                )
            })
            .collect()
    }

    pub fn plan_crop_snapshot<F>(
        crop_id: i64,
        crop_name: impl Into<String>,
        groups: Value,
        crop_stage_count: i32,
        build_agrr_requirement: Option<F>,
    ) -> PlanAllocationAdjustPlanCropSnapshot
    where
        F: FnOnce() -> Value,
    {
        let has_growth = Self::has_growth_stages(crop_stage_count);
        let requirement = if has_growth {
            build_agrr_requirement.map(|f| f())
        } else {
            None
        };

        PlanAllocationAdjustPlanCropSnapshot::new(
            crop_id,
            crop_name,
            groups,
            has_growth,
            requirement,
        )
    }

    pub fn weather_location_facts(
        weather_location: &WeatherLocation,
    ) -> BTreeMap<String, Value> {
        BTreeMap::from([
            ("latitude".into(), json!(weather_location.latitude)),
            ("longitude".into(), json!(weather_location.longitude)),
            (
                "elevation".into(),
                json!(weather_location.elevation.unwrap_or(0.0)),
            ),
            (
                "timezone".into(),
                json!(weather_location.timezone.clone().unwrap_or_default()),
            ),
        ])
    }

    fn field_cultivation_allocation_snapshot(
        field_cultivation: &PlanAllocationAdjustFieldCultivationSnapshot,
    ) -> PlanAllocationAdjustFieldCultivationAllocationSnapshot {
        PlanAllocationAdjustFieldCultivationAllocationSnapshot::new(
            field_cultivation.field_cultivation_id,
            field_cultivation.field_id,
            field_cultivation.crop_id.to_string(),
            field_cultivation.crop_name.clone(),
            field_cultivation.variety.clone(),
            field_cultivation.area,
            field_cultivation.start_date,
            field_cultivation.completion_date,
            Self::effective_cultivation_days(
                field_cultivation.stored_cultivation_days,
                field_cultivation.start_date,
                field_cultivation.completion_date,
            ),
            Self::effective_estimated_cost(field_cultivation.estimated_cost),
            revenue_from_optimization_result(field_cultivation.optimization_result.as_ref()),
            accumulated_gdd_from_optimization_result(
                field_cultivation.optimization_result.as_ref(),
            ),
            Self::has_growth_stages(field_cultivation.crop_stage_count),
        )
    }
}

fn revenue_from_optimization_result(opt: Option<&Value>) -> f64 {
    let Some(Value::Object(map)) = opt else {
        return 0.0;
    };
    map.get("revenue")
        .or_else(|| map.get("expected_revenue"))
        .and_then(|v| v.as_f64())
        .unwrap_or(0.0)
}

fn accumulated_gdd_from_optimization_result(opt: Option<&Value>) -> f64 {
    let Some(Value::Object(map)) = opt else {
        return 0.0;
    };
    if let Some(v) = map.get("accumulated_gdd").and_then(|v| v.as_f64()) {
        return v;
    }
    map.get("raw")
        .and_then(|raw| raw.get("total_gdd"))
        .and_then(|v| v.as_f64())
        .unwrap_or(0.0)
}

#[cfg(test)]
mod mappers_plan_allocation_adjust_read_snapshot_parts_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/mappers_plan_allocation_adjust_read_snapshot_parts_test.rs"));
}
