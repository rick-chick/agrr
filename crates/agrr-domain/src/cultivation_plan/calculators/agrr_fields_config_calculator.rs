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
mod tests {
    use super::*;

    // Ruby: test "build maps fields and defaults daily_fixed_cost"
    #[test]
    fn build_maps_fields_and_defaults_daily_fixed_cost() {
        let plan_fields = vec![AgrrPlanFieldRow {
            id: "10".into(),
            name: "Field A".into(),
            area: 1.25,
            daily_fixed_cost: None,
        }];
        let result = build(&plan_fields);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0]["field_id"], "10");
        assert_eq!(result[0]["name"], "Field A");
        assert_eq!(result[0]["area"], 1.25);
        assert_eq!(result[0]["daily_fixed_cost"], 0.0);
    }
}
