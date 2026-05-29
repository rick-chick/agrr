//! Ruby: `Domain::CultivationPlan::Calculators::AgrrCurrentAllocationCalculator`

use serde_json::{json, Value};
use time::Date;

#[derive(Debug, Clone)]
pub struct AgrrAllocationRow {
    pub allocation_id: i64,
    pub crop_id: String,
    pub crop_name: String,
    pub variety: Option<String>,
    pub area_used: f64,
    pub start_date: Option<Date>,
    pub completion_date: Option<Date>,
    pub growth_days: i32,
    pub accumulated_gdd: f64,
    pub total_cost: f64,
    pub expected_revenue: f64,
}

#[derive(Debug, Clone)]
pub struct AgrrFieldRow {
    pub field_id: i64,
    pub field_name: String,
    pub field_area: f64,
    pub allocations: Vec<AgrrAllocationRow>,
}

pub fn build(cultivation_plan_id: i64, field_rows: &[AgrrFieldRow]) -> Value {
    let mut field_schedules = Vec::new();

    for row in field_rows {
        let mut allocations = Vec::new();
        for a in &row.allocations {
            let revenue = a.expected_revenue;
            let cost = a.total_cost;
            let profit = revenue - cost;
            allocations.push(json!({
                "allocation_id": a.allocation_id,
                "crop_id": a.crop_id,
                "crop_name": a.crop_name,
                "variety": a.variety,
                "area_used": a.area_used,
                "start_date": format_optional_date(a.start_date),
                "completion_date": format_optional_date(a.completion_date),
                "growth_days": a.growth_days,
                "accumulated_gdd": a.accumulated_gdd,
                "total_cost": cost,
                "expected_revenue": revenue,
                "profit": profit,
            }));
        }

        let field_total_cost: f64 = allocations
            .iter()
            .filter_map(|x| x.get("total_cost").and_then(|v| v.as_f64()))
            .sum();
        let field_total_revenue: f64 = allocations
            .iter()
            .filter_map(|x| x.get("expected_revenue").and_then(|v| v.as_f64()))
            .sum();
        let field_total_profit: f64 = allocations
            .iter()
            .filter_map(|x| x.get("profit").and_then(|v| v.as_f64()))
            .sum();
        let field_area_used: f64 = allocations
            .iter()
            .filter_map(|x| x.get("area_used").and_then(|v| v.as_f64()))
            .sum();
        let field_utilization_rate = if row.field_area > 0.0 {
            field_area_used / row.field_area
        } else {
            0.0
        };

        field_schedules.push(json!({
            "field_id": row.field_id.to_string(),
            "field_name": row.field_name,
            "total_cost": field_total_cost,
            "total_revenue": field_total_revenue,
            "total_profit": field_total_profit,
            "utilization_rate": field_utilization_rate,
            "allocations": allocations,
        }));
    }

    let total_cost: f64 = field_schedules
        .iter()
        .filter_map(|fs| fs.get("total_cost").and_then(|v| v.as_f64()))
        .sum();
    let total_revenue: f64 = field_schedules
        .iter()
        .filter_map(|fs| fs.get("total_revenue").and_then(|v| v.as_f64()))
        .sum();
    let total_profit: f64 = field_schedules
        .iter()
        .filter_map(|fs| fs.get("total_profit").and_then(|v| v.as_f64()))
        .sum();

    json!({
        "optimization_result": {
            "optimization_id": format!("opt_{cultivation_plan_id}"),
            "total_cost": total_cost,
            "total_revenue": total_revenue,
            "total_profit": total_profit,
            "field_schedules": field_schedules,
        }
    })
}

fn format_optional_date(value: Option<Date>) -> Option<String> {
    value.map(|d| d.to_string())
}

#[cfg(test)]
mod calculators_agrr_current_allocation_calculator_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/calculators_agrr_current_allocation_calculator_test.rs"));
}
