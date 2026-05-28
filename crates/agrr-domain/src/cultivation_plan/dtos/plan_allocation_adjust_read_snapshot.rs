//! Ruby: `Domain::CultivationPlan::Dtos::PlanAllocationAdjustReadSnapshot`

use std::collections::HashMap;

use serde_json::Value;
use time::Date;

use super::plan_allocation_adjust_field_source_snapshot::PlanAllocationAdjustFieldSourceSnapshot;
use crate::field_cultivation::dtos::WeatherPredictionTargets;
use crate::weather_data::dtos::CultivationPlanWeather;

/// Ruby: `PlanAllocationAdjustReadSnapshot::PlanFieldSnapshot`
#[derive(Debug, Clone)]
pub struct PlanAllocationAdjustPlanFieldSnapshot {
    pub id: i64,
    pub name: String,
    pub area: f64,
    pub daily_fixed_cost: f64,
}

impl PlanAllocationAdjustPlanFieldSnapshot {
    pub fn new(id: i64, name: impl Into<String>, area: f64, daily_fixed_cost: f64) -> Self {
        Self {
            id,
            name: name.into(),
            area,
            daily_fixed_cost,
        }
    }
}

/// Ruby: `PlanAllocationAdjustReadSnapshot::PlanCropSnapshot`
#[derive(Debug, Clone)]
pub struct PlanAllocationAdjustPlanCropSnapshot {
    pub crop_id: i64,
    pub crop_name: String,
    pub groups: Value,
    pub has_growth_stages: bool,
    pub agrr_requirement: Option<Value>,
}

impl PlanAllocationAdjustPlanCropSnapshot {
    pub fn new(
        crop_id: i64,
        crop_name: impl Into<String>,
        groups: Value,
        has_growth_stages: bool,
        agrr_requirement: Option<Value>,
    ) -> Self {
        Self {
            crop_id,
            crop_name: crop_name.into(),
            groups,
            has_growth_stages,
            agrr_requirement,
        }
    }
}

#[derive(Debug, Clone)]
pub struct PlanAllocationAdjustCultivationPeriod {
    pub start_date: Option<Date>,
    pub completion_date: Option<Date>,
}

#[derive(Debug, Clone)]
pub struct PlanAllocationAdjustPlanningBoundaries {
    pub planning_start_date: Option<Date>,
    pub planning_end_date: Option<Date>,
}

/// Ruby: `Domain::CultivationPlan::Dtos::PlanAllocationAdjustReadSnapshot`
#[derive(Debug, Clone)]
pub struct PlanAllocationAdjustReadSnapshot {
    pub plan_id: i64,
    pub field_source_snapshots: Vec<PlanAllocationAdjustFieldSourceSnapshot>,
    pub plan_field_snapshots: Vec<PlanAllocationAdjustPlanFieldSnapshot>,
    pub plan_crop_snapshots: Vec<PlanAllocationAdjustPlanCropSnapshot>,
    pub cultivation_planning_periods: Vec<PlanAllocationAdjustCultivationPeriod>,
    pub planning_period_boundaries: PlanAllocationAdjustPlanningBoundaries,
    pub cultivation_plan_weather_dto: CultivationPlanWeather,
    pub weather_prediction_targets: WeatherPredictionTargets,
    pub weather_location_facts: HashMap<String, Value>,
    pub farm_without_weather_location: bool,
}

impl PlanAllocationAdjustReadSnapshot {
    pub fn minimal_for_tests(
        plan_id: i64,
        crop_name: impl Into<String>,
        has_growth_stages: bool,
    ) -> Self {
        Self {
            plan_id,
            field_source_snapshots: vec![],
            plan_field_snapshots: vec![],
            plan_crop_snapshots: vec![PlanAllocationAdjustPlanCropSnapshot::new(
                1,
                crop_name,
                Value::Array(vec![]),
                has_growth_stages,
                None,
            )],
            cultivation_planning_periods: vec![],
            planning_period_boundaries: PlanAllocationAdjustPlanningBoundaries {
                planning_start_date: None,
                planning_end_date: None,
            },
            cultivation_plan_weather_dto: CultivationPlanWeather::new(2, None, None, None),
            weather_prediction_targets: WeatherPredictionTargets {
                weather_location: Value::Null,
                farm: Value::Null,
            },
            weather_location_facts: HashMap::new(),
            farm_without_weather_location: true,
        }
    }
}
