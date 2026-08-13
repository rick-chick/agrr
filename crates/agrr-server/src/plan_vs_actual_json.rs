//! JSON shape for `GET /api/v1/plans/:id/plan_vs_actual/summary`.

use agrr_domain::cultivation_plan::dtos::{
    PlanVarianceActionItemRead, PlanVsActualCategorySummaryRead, PlanVsActualItemRead,
    PlanVsActualSummaryRead, StageGddCalibrationProposalRead,
};
use agrr_domain::cultivation_plan::policies::plan_variance_threshold_policy::VarianceExceedanceKind;
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
        "stage_gdd_calibration_proposals": summary
            .stage_gdd_calibration_proposals
            .iter()
            .map(stage_gdd_calibration_proposal_payload)
            .collect::<Vec<_>>(),
        "action_required_items": summary
            .action_required_items
            .iter()
            .map(action_item_payload)
            .collect::<Vec<_>>(),
    })
}

fn stage_gdd_calibration_proposal_payload(
    proposal: &StageGddCalibrationProposalRead,
) -> Value {
    json!({
        "crop_id": proposal.crop_id,
        "crop_name": proposal.crop_name,
        "stage_order": proposal.stage_order,
        "stage_name": proposal.stage_name,
        "average_gdd_delta": proposal.average_gdd_delta,
        "recorded_item_count": proposal.recorded_item_count,
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

fn action_item_payload(item: &PlanVarianceActionItemRead) -> Value {
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
        "exceedance_kind": exceedance_kind_payload(item.exceedance_kind),
    })
}

fn exceedance_kind_payload(kind: VarianceExceedanceKind) -> &'static str {
    kind.as_str()
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
            stage_gdd_calibration_proposals: vec![StageGddCalibrationProposalRead {
                crop_id: 42,
                crop_name: "Tomato".into(),
                stage_order: 1,
                stage_name: "Vegetative".into(),
                average_gdd_delta: 10.5,
                recorded_item_count: 2,
            }],
            action_required_items: vec![PlanVarianceActionItemRead {
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
                exceedance_kind: VarianceExceedanceKind::Both,
            }],
        });

        assert_eq!(7, body["plan_id"].as_i64().unwrap());
        assert_eq!(2, body["unrecorded_count"].as_i64().unwrap());
        assert_eq!(3.5, body["categories"][0]["average_delta_days"].as_f64().unwrap());
        assert_eq!(7, body["top_variance_items"][0]["delta_days"].as_i64().unwrap());
        assert_eq!(130.5, body["top_variance_items"][0]["gdd_at_actual"].as_f64().unwrap());
        assert_eq!(
            10.5,
            body["stage_gdd_calibration_proposals"][0]["average_gdd_delta"]
                .as_f64()
                .unwrap()
        );
        assert_eq!(1, body["action_required_items"].as_array().unwrap().len());
        assert_eq!(
            "both",
            body["action_required_items"][0]["exceedance_kind"].as_str().unwrap()
        );
    }
}
