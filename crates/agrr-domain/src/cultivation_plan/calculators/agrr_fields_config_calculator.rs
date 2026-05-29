//! Ruby: `Domain::CultivationPlan::Calculators::AgrrFieldsConfigCalculator`

use serde_json::{json, Value};

#[derive(Debug, Clone)]
pub struct AgrrPlanFieldRow {
    pub id: String,
    pub name: String,
    pub area: f64,
    pub daily_fixed_cost: Option<f64>,
}

pub fn build(plan_fields: &[AgrrPlanFieldRow]) -> Vec<Value> {
    plan_fields
        .iter()
        .map(|field| {
            json!({
                "field_id": field.id,
                "name": field.name,
                "area": field.area,
                "daily_fixed_cost": field.daily_fixed_cost.unwrap_or(0.0),
            })
        })
        .collect()
}

#[cfg(test)]
mod calculators_agrr_fields_config_calculator_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/calculators_agrr_fields_config_calculator_test.rs"));
}
