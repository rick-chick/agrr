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
mod tests {
    use super::*;
    use time::Month;

    fn d(y: i32, m: u8, day: u8) -> Date {
        Date::from_calendar_date(y, Month::try_from(m).unwrap(), day).unwrap()
    }

    // Ruby: test "build aggregates optimization_result from field rows"
    #[test]
    fn build_aggregates_optimization_result_from_field_rows() {
        let field_rows = vec![
            AgrrFieldRow {
                field_id: 1,
                field_name: "North".into(),
                field_area: 100.0,
                allocations: vec![AgrrAllocationRow {
                    allocation_id: 10,
                    crop_id: "5".into(),
                    crop_name: "Tomato".into(),
                    variety: Some("A".into()),
                    area_used: 40.0,
                    start_date: Some(d(2025, 4, 1)),
                    completion_date: Some(d(2025, 7, 1)),
                    growth_days: 92,
                    accumulated_gdd: 1.5,
                    total_cost: 100.0,
                    expected_revenue: 300.0,
                }],
            },
            AgrrFieldRow {
                field_id: 2,
                field_name: "South".into(),
                field_area: 50.0,
                allocations: vec![],
            },
        ];

        let result = build(42, &field_rows);
        let opt = &result["optimization_result"];
        assert_eq!(opt["optimization_id"], "opt_42");
        assert!((opt["total_cost"].as_f64().unwrap() - 100.0).abs() < 0.001);
        assert!((opt["total_revenue"].as_f64().unwrap() - 300.0).abs() < 0.001);
        assert!((opt["total_profit"].as_f64().unwrap() - 200.0).abs() < 0.001);

        let schedules = opt["field_schedules"].as_array().unwrap();
        assert_eq!(schedules.len(), 2);

        let first = &schedules[0];
        assert_eq!(first["field_id"], "1");
        assert_eq!(first["field_name"], "North");
        assert!((first["utilization_rate"].as_f64().unwrap() - 0.4).abs() < 0.001);
        let alloc = &first["allocations"][0];
        assert_eq!(alloc["allocation_id"], 10);
        assert_eq!(alloc["crop_id"], "5");
        assert_eq!(alloc["start_date"], "2025-04-01");
        assert_eq!(alloc["completion_date"], "2025-07-01");
        assert!((alloc["profit"].as_f64().unwrap() - 200.0).abs() < 0.001);

        let last = &schedules[1];
        assert!(last["allocations"].as_array().unwrap().is_empty());
        assert!((last["utilization_rate"].as_f64().unwrap()).abs() < 0.001);
    }
}
