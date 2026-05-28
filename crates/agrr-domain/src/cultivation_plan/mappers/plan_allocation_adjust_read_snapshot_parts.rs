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
mod tests {
    use super::*;
    use serde_json::json;
    use time::macros::date;

    // Ruby: test "build_field_source_snapshots normalizes optimize-style optimization_result keys"
    #[test]
    fn build_field_source_snapshots_normalizes_optimize_style_optimization_result_keys() {
        let plan_field_snapshots = vec![PlanAllocationAdjustPlanFieldSnapshot::new(
            2, "North", 100.0, 5.0,
        )];
        let field_cultivation = PlanAllocationAdjustFieldCultivationSnapshot::new(
            10,
            2,
            5,
            "Tomato",
            None,
            12.0,
            date!(2026-04-01),
            date!(2026-04-20),
            Some(20),
            1,
            Some(100.0),
            Some(json!({
                "expected_revenue": 200.0,
                "profit": 100.0,
                "raw": { "total_gdd": 42.0 }
            })),
        );

        let snapshots = PlanAllocationAdjustReadSnapshotParts::build_field_source_snapshots(
            &plan_field_snapshots,
            &[field_cultivation],
        );
        let source = &snapshots[0].cultivations[0];

        assert!((source.revenue - 200.0).abs() < 0.001);
        assert!((source.accumulated_gdd - 42.0).abs() < 0.001);
        assert_eq!(source.cultivation_days, 20);
        assert!(source.has_growth_stages);
    }

    // Ruby: test "build_field_source_snapshots derives cultivation_days when stored is nil"
    #[test]
    fn build_field_source_snapshots_derives_cultivation_days_when_stored_is_nil() {
        let plan_field_snapshots = vec![PlanAllocationAdjustPlanFieldSnapshot::new(
            1, "A", 10.0, 1.0,
        )];
        let field_cultivation = PlanAllocationAdjustFieldCultivationSnapshot::new(
            1,
            1,
            1,
            "C",
            None,
            1.0,
            date!(2026-01-01),
            date!(2026-01-10),
            None,
            0,
            None,
            None,
        );

        let source = PlanAllocationAdjustReadSnapshotParts::build_field_source_snapshots(
            &plan_field_snapshots,
            &[field_cultivation],
        )[0]
        .cultivations[0]
        .clone();

        assert_eq!(source.cultivation_days, 10);
        assert!(!source.has_growth_stages);
        assert!(source.estimated_cost.abs() < 0.001);
    }

    // Ruby: test "plan_crop_snapshot invokes build_agrr_requirement only when crop has growth stages"
    #[test]
    fn plan_crop_snapshot_invokes_build_agrr_requirement_only_when_crop_has_growth_stages() {
        let mut called = false;
        let entry = PlanAllocationAdjustReadSnapshotParts::plan_crop_snapshot(
            1,
            "Tomato",
            json!([]),
            2,
            Some(|| {
                called = true;
                json!({ "stages": [] })
            }),
        );

        assert!(called);
        assert!(entry.has_growth_stages);
        assert_eq!(entry.agrr_requirement, Some(json!({ "stages": [] })));

        called = false;
        let entry = PlanAllocationAdjustReadSnapshotParts::plan_crop_snapshot(
            2,
            "Bare",
            json!([]),
            0,
            Some(|| {
                called = true;
                json!({})
            }),
        );

        assert!(!called);
        assert!(!entry.has_growth_stages);
        assert!(entry.agrr_requirement.is_none());
    }

    // Ruby: test "effective_cultivation_days returns stored value when present"
    #[test]
    fn effective_cultivation_days_returns_stored_value_when_present() {
        let days = PlanAllocationAdjustReadSnapshotParts::effective_cultivation_days(
            Some(15),
            date!(2026-04-01),
            date!(2026-04-30),
        );
        assert_eq!(days, 15);
    }

    // Ruby: test "effective_cultivation_days derives inclusive days from date range when stored is nil"
    #[test]
    fn effective_cultivation_days_derives_inclusive_days_from_date_range_when_stored_is_nil() {
        let days = PlanAllocationAdjustReadSnapshotParts::effective_cultivation_days(
            None,
            date!(2026-04-01),
            date!(2026-04-20),
        );
        assert_eq!(days, 20);
    }

    // Ruby: test "has_growth_stages? is true when crop_stage_count is positive"
    #[test]
    fn has_growth_stages_is_true_when_crop_stage_count_is_positive() {
        assert!(PlanAllocationAdjustReadSnapshotParts::has_growth_stages(2));
    }

    // Ruby: test "has_growth_stages? is false when crop_stage_count is zero"
    #[test]
    fn has_growth_stages_is_false_when_crop_stage_count_is_zero() {
        assert!(!PlanAllocationAdjustReadSnapshotParts::has_growth_stages(0));
    }

    // Ruby: test "weather_location_facts reads WeatherLocation DTO"
    #[test]
    fn weather_location_facts_reads_weather_location_dto() {
        let wl = WeatherLocation::new(
            9,
            35.0,
            135.0,
            Some(10.0),
            Some("Asia/Tokyo".into()),
            None,
        );

        let facts = PlanAllocationAdjustReadSnapshotParts::weather_location_facts(&wl);

        assert!((facts["latitude"].as_f64().unwrap() - 35.0).abs() < 0.001);
        assert!((facts["longitude"].as_f64().unwrap() - 135.0).abs() < 0.001);
        assert!((facts["elevation"].as_f64().unwrap() - 10.0).abs() < 0.001);
        assert_eq!(facts["timezone"].as_str(), Some("Asia/Tokyo"));
    }
}
