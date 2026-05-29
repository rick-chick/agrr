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
