//! Ruby: `Adapters::CultivationPlan::Mappers::CultivationPlanWorkbenchPayloadMapper`

use agrr_domain::cultivation_plan::dtos::cultivation_plan_workbench::CultivationPlanWorkbenchSnapshot;
use serde_json::{json, Value};

pub fn to_json_body(snapshot: CultivationPlanWorkbenchSnapshot) -> Value {
    let p = snapshot.plan;
    json!({
        "success": true,
        "data": {
            "id": p.id,
            "plan_year": p.plan_year,
            "plan_name": p.plan_name,
            "plan_type": p.plan_type,
            "status": p.status,
            "total_area": p.total_area,
            "planning_start_date": p.planning_start_date,
            "planning_end_date": p.planning_end_date,
            "fields": snapshot.fields,
            "crops": snapshot.crops,
            "available_crops": snapshot.available_crop_rows,
            "cultivations": snapshot.cultivations,
        },
        "total_profit": p.total_profit,
        "total_revenue": p.total_revenue,
        "total_cost": p.total_cost,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::cultivation_plan::dtos::cultivation_plan_workbench::{
        CultivationPlanWorkbenchPlanHeader, CultivationPlanWorkbenchSnapshot,
    };
    use serde_json::json;

    #[test]
    fn to_json_body_maps_header_nested_collections_and_economics() {
        let body = to_json_body(CultivationPlanWorkbenchSnapshot {
            plan: CultivationPlanWorkbenchPlanHeader {
                id: 9,
                user_id: Some(1),
                plan_year: Some(2026),
                plan_name: Some("Bench".into()),
                plan_type: "private".into(),
                status: "completed".into(),
                total_area: 12.5,
                planning_start_date: Some("2026-01-01".into()),
                planning_end_date: Some("2026-12-31".into()),
                total_profit: 100.0,
                total_revenue: 300.0,
                total_cost: 200.0,
            },
            fields: vec![json!({"id": 1, "name": "North"})],
            crops: vec![json!({"id": 2})],
            cultivations: vec![json!({"id": 3})],
            available_crop_rows: vec![json!({"crop_id": 4})],
            farm_region: "jp".into(),
        });

        assert_eq!(body["success"], true);
        assert_eq!(body["data"]["id"], 9);
        assert_eq!(body["data"]["plan_name"], "Bench");
        assert_eq!(body["data"]["fields"][0]["name"], "North");
        assert_eq!(body["data"]["available_crops"][0]["crop_id"], 4);
        assert_eq!(body["total_profit"], 100.0);
        assert_eq!(body["total_revenue"], 300.0);
        assert_eq!(body["total_cost"], 200.0);
    }
}
