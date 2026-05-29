//! Ruby: `Domain::CultivationPlan::Mappers::CultivationPlanWorkbenchSnapshotMapper`

use crate::cultivation_plan::dtos::CropRowsAvailableRow;
use crate::cultivation_plan::dtos::cultivation_plan_workbench::{
    CultivationPlanWorkbenchPlanHeader, CultivationPlanWorkbenchSnapshot,
};
use crate::cultivation_plan::dtos::rest_plan_snapshots::CultivationPlanRestPlanSnapshot;
use serde_json::{json, Value};

pub fn from_snapshots(
    rest_plan_snapshot: CultivationPlanRestPlanSnapshot,
    available_crop_rows: Vec<CropRowsAvailableRow>,
) -> CultivationPlanWorkbenchSnapshot {
    from_rest_plan_snapshot(rest_plan_snapshot, available_crop_rows)
}

pub fn from_rest_plan_snapshot(
    snapshot: CultivationPlanRestPlanSnapshot,
    available_crop_rows: Vec<CropRowsAvailableRow>,
) -> CultivationPlanWorkbenchSnapshot {
    let plan = CultivationPlanWorkbenchPlanHeader {
        id: snapshot.id,
        user_id: snapshot.user_id,
        plan_year: snapshot.plan_year,
        plan_name: snapshot.plan_name,
        plan_type: snapshot.plan_type,
        status: snapshot.status,
        total_area: snapshot.total_area,
        planning_start_date: snapshot.calculated_planning_start_date,
        planning_end_date: snapshot.prediction_target_end_date,
        total_profit: snapshot.total_profit,
        total_revenue: snapshot.total_revenue,
        total_cost: snapshot.total_cost,
    };

    let fields: Vec<Value> = snapshot
        .field_rows
        .into_iter()
        .map(|field| {
            json!({
                "id": field.id,
                "field_id": field.id,
                "name": field.display_name,
                "area": field.area,
                "daily_fixed_cost": field.daily_fixed_cost,
            })
        })
        .collect();

    let crops: Vec<Value> = snapshot
        .crop_rows
        .into_iter()
        .map(|crop| {
            json!({
                "id": crop.id,
                "name": crop.display_name,
                "area_per_unit": crop.area_per_unit,
                "revenue_per_area": crop.revenue_per_area,
            })
        })
        .collect();

    let cultivations: Vec<Value> = snapshot
        .cultivation_rows
        .into_iter()
        .map(|fc| {
            let revenue = optimization_result_f64(&fc.optimization_result, "revenue");
            let profit = optimization_result_f64(&fc.optimization_result, "profit");
            json!({
                "id": fc.id,
                "field_id": fc.cultivation_plan_field_id,
                "field_name": fc.field_display_name,
                "crop_id": fc.cultivation_plan_crop_id,
                "crop_name": fc.crop_display_name,
                "area": fc.area,
                "start_date": fc.start_date,
                "completion_date": fc.completion_date,
                "cultivation_days": fc.cultivation_days,
                "estimated_cost": fc.estimated_cost,
                "revenue": revenue,
                "profit": profit,
                "status": fc.status,
            })
        })
        .collect();

    let available: Vec<Value> = available_crop_rows
        .into_iter()
        .map(|row| {
            json!({
                "id": row.id,
                "name": row.name,
                "variety": row.variety,
                "area_per_unit": row.area_per_unit,
            })
        })
        .collect();

    CultivationPlanWorkbenchSnapshot {
        plan,
        fields,
        crops,
        cultivations,
        available_crop_rows: available,
        farm_region: snapshot.farm_region,
    }
}

fn optimization_result_f64(raw: &Option<String>, key: &str) -> f64 {
    let Some(s) = raw else {
        return 0.0;
    };
    let Ok(v) = serde_json::from_str::<Value>(s) else {
        return 0.0;
    };
    v.get(key)
        .and_then(|n| n.as_f64())
        .unwrap_or(0.0)
}
