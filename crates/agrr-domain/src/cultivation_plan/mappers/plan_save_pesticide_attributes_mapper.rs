//! Ruby: `Domain::CultivationPlan::Mappers::PlanSavePesticideAttributesMapper`

use std::collections::BTreeMap;

use serde_json::{json, Value};

use crate::cultivation_plan::dtos::PublicPlanSavePesticideReferenceRow;

pub struct PlanSavePesticideAttributesMapper;

impl PlanSavePesticideAttributesMapper {
    pub fn attributes_for_create(
        row: &PublicPlanSavePesticideReferenceRow,
        region: Option<&str>,
        user_crop_id: i64,
        user_pest_id: i64,
    ) -> BTreeMap<String, Value> {
        BTreeMap::from([
            ("crop_id".into(), json!(user_crop_id)),
            ("pest_id".into(), json!(user_pest_id)),
            ("name".into(), json!(row.name)),
            ("active_ingredient".into(), json!(row.active_ingredient)),
            ("description".into(), json!(row.description)),
            (
                "region".into(),
                json!(row.region.clone().or_else(|| region.map(str::to_string))),
            ),
            ("is_reference".into(), json!(false)),
            (
                "source_pesticide_id".into(),
                json!(row.reference_pesticide_id),
            ),
        ])
    }

    pub fn usage_constraint_attributes(
        row: &PublicPlanSavePesticideReferenceRow,
    ) -> Option<BTreeMap<String, Value>> {
        let constraint = row.usage_constraint.as_ref()?;
        Some(BTreeMap::from([
            (
                "min_temperature".into(),
                json!(constraint.min_temperature),
            ),
            (
                "max_temperature".into(),
                json!(constraint.max_temperature),
            ),
            (
                "max_wind_speed_m_s".into(),
                json!(constraint.max_wind_speed_m_s),
            ),
            (
                "max_application_count".into(),
                json!(constraint.max_application_count),
            ),
            (
                "harvest_interval_days".into(),
                json!(constraint.harvest_interval_days),
            ),
            (
                "other_constraints".into(),
                json!(constraint.other_constraints),
            ),
        ]))
    }

    pub fn application_detail_attributes(
        row: &PublicPlanSavePesticideReferenceRow,
    ) -> Option<BTreeMap<String, Value>> {
        let detail = row.application_detail.as_ref()?;
        Some(BTreeMap::from([
            ("dilution_ratio".into(), json!(detail.dilution_ratio)),
            ("amount_per_m2".into(), json!(detail.amount_per_m2)),
            ("amount_unit".into(), json!(detail.amount_unit)),
            (
                "application_method".into(),
                json!(detail.application_method),
            ),
        ]))
    }
}

#[cfg(test)]
mod mappers_plan_save_pesticide_attributes_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/mappers_plan_save_pesticide_attributes_mapper_test.rs"));
}
