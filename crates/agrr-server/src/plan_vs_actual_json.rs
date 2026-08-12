//! JSON shape for `GET /api/v1/plans/:id/plan_vs_actual/summary`.

use agrr_domain::cultivation_plan::dtos::{
    PlanVsActualCategorySummaryRead, PlanVsActualItemRead, PlanVsActualSummaryRead,
};
use serde_json::{json, Value};

pub fn summary_to_json_body(summary: PlanVsActualSummaryRead) -> Value {
    json!({
        "plan_id": summary.plan_id,
        "unrecorded_count": summary.unrecorded_count,
        "categories": summary.categories.iter().map(category_payload).collect::<Vec<_>>(),
        "top_variance_items": summary
            .top_variance_items
            .iter()
            .map(item_payload)
            .collect::<Vec<_>>(),
    })
}

fn category_payload(category: &PlanVsActualCategorySummaryRead) -> Value {
    json!({
        "category": category.category,
        "average_delta_days": category.average_delta_days,
        "item_count": category.item_count,
        "recorded_count": category.recorded_count,
    })
}

fn item_payload(item: &PlanVsActualItemRead) -> Value {
    json!({
        "item_id": item.item_id,
        "field_cultivation_id": item.field_cultivation_id,
        "category": item.category,
        "name": item.name,
        "scheduled_date": item.scheduled_date,
        "actual_date": item.actual_date,
        "delta_days": item.delta_days,
        "gdd_trigger": optional_f64(item.gdd_trigger),
        "gdd_at_actual": optional_f64(item.gdd_at_actual),
        "gdd_delta": optional_f64(item.gdd_delta),
    })
}

fn optional_f64(value: Option<f64>) -> Value {
    value.map(|v| json!(v)).unwrap_or(Value::Null)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn summary_payload_includes_category_averages_and_top_items() {
        let body = summary_to_json_body(PlanVsActualSummaryRead {
            plan_id: 7,
            unrecorded_count: 2,
            categories: vec![PlanVsActualCategorySummaryRead {
                category: "general".into(),
                average_delta_days: Some(3.5),
                item_count: 4,
                recorded_count: 2,
            }],
            top_variance_items: vec![PlanVsActualItemRead {
                item_id: 11,
                field_cultivation_id: 100,
                category: "general".into(),
                name: "Weed".into(),
                scheduled_date: Some("2026-06-01".into()),
                actual_date: Some("2026-06-08".into()),
                delta_days: Some(7),
                gdd_trigger: Some(120.0),
                gdd_at_actual: Some(130.5),
                gdd_delta: Some(10.5),
            }],
        });

        assert_eq!(7, body["plan_id"].as_i64().unwrap());
        assert_eq!(2, body["unrecorded_count"].as_i64().unwrap());
        assert_eq!(3.5, body["categories"][0]["average_delta_days"].as_f64().unwrap());
        assert_eq!(7, body["top_variance_items"][0]["delta_days"].as_i64().unwrap());
        assert_eq!(130.5, body["top_variance_items"][0]["gdd_at_actual"].as_f64().unwrap());
    }
}
