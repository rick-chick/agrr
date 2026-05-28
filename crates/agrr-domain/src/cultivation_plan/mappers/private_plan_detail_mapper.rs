//! Ruby: `Domain::CultivationPlan::Mappers::PrivatePlanDetailMapper`

use crate::crop::entities::CropEntity;
use crate::cultivation_plan::dtos::{
    PrivateCultivationPlanDetail, PrivatePlanReadSnapshot, PrivatePlanShowPaletteCrop,
};

pub fn to_detail(
    snapshot: &PrivatePlanReadSnapshot,
    palette_crop_entities: &[CropEntity],
) -> PrivateCultivationPlanDetail {
    let mut palette_crops: Vec<PrivatePlanShowPaletteCrop> = palette_crop_entities
        .iter()
        .map(|crop| PrivatePlanShowPaletteCrop {
            id: crop.id,
            name: crop.name.clone(),
            variety: crop.variety.clone(),
        })
        .collect();
    palette_crops.sort_by(|a, b| a.name.cmp(&b.name));

    PrivateCultivationPlanDetail {
        id: snapshot.id,
        display_name: snapshot.display_name.clone(),
        farm_display_name: snapshot.farm_display_name.clone(),
        total_area: snapshot.total_area,
        field_cultivations_count: snapshot.field_cultivations_count,
        cultivation_plan_fields_count: snapshot.cultivation_plan_fields_count,
        planning_start_date: snapshot.planning_start_date,
        planning_end_date: snapshot.planning_end_date,
        status: snapshot.status.clone(),
        field_cultivations: snapshot.field_cultivations.clone(),
        cultivation_plan_fields: snapshot.cultivation_plan_fields.clone(),
        palette_used_crop_ids: snapshot.palette_used_crop_ids.clone(),
        palette_crops,
    }
}
