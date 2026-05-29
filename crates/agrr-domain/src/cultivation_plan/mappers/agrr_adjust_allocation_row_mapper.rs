//! Ruby: `Domain::CultivationPlan::Mappers::AgrrAdjustAllocationRowMapper`

use serde_json::Value;

use crate::cultivation_plan::calculators::agrr_current_allocation_calculator::{
    build, AgrrAllocationRow, AgrrFieldRow,
};
use crate::cultivation_plan::dtos::PlanAllocationAdjustFieldSourceSnapshot;

pub fn build_current_allocation(
    cultivation_plan_id: i64,
    field_snapshots: &[PlanAllocationAdjustFieldSourceSnapshot],
    exclude_ids: &[i64],
) -> Value {
    let prepared: Vec<AgrrFieldRow> = field_snapshots
        .iter()
        .map(|field_snapshot| {
            let allocations: Vec<AgrrAllocationRow> = field_snapshot
                .cultivations
                .iter()
                .filter(|row| {
                    !exclude_ids.contains(&row.field_cultivation_id) && row.has_growth_stages
                })
                .map(|snapshot| {
                    let revenue = snapshot.revenue;
                    let cost = snapshot.estimated_cost;
                    AgrrAllocationRow {
                        allocation_id: snapshot.field_cultivation_id,
                        crop_id: snapshot.crop_id.clone(),
                        crop_name: snapshot.crop_name.clone(),
                        variety: snapshot.variety.clone(),
                        area_used: snapshot.area,
                        start_date: Some(snapshot.start_date),
                        completion_date: Some(snapshot.completion_date),
                        growth_days: snapshot.cultivation_days,
                        accumulated_gdd: snapshot.accumulated_gdd,
                        total_cost: cost,
                        expected_revenue: revenue,
                    }
                })
                .collect();

            AgrrFieldRow {
                field_id: field_snapshot.field_id,
                field_name: field_snapshot.field_name.clone(),
                field_area: field_snapshot.field_area,
                allocations,
            }
        })
        .collect();

    build(cultivation_plan_id, &prepared)
}

#[cfg(test)]
mod mappers_agrr_adjust_allocation_row_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/mappers_agrr_adjust_allocation_row_mapper_test.rs"));
}
