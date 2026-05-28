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
mod tests {
    use super::*;
    use crate::cultivation_plan::dtos::{
        PublicPlanSavePesticideApplicationDetailRow, PublicPlanSavePesticideUsageConstraintRow,
    };

    fn build_row(
        with_constraint: bool,
        with_detail: bool,
    ) -> PublicPlanSavePesticideReferenceRow {
        let usage_constraint = with_constraint.then(|| {
            PublicPlanSavePesticideUsageConstraintRow::new(
                Some(5.0),
                Some(35.0),
                None,
                Some(2),
                None,
                None,
            )
        });
        let application_detail = with_detail.then(|| {
            PublicPlanSavePesticideApplicationDetailRow::new(
                Some("1000倍".into()),
                Some(0.5),
                Some("g".into()),
                Some("散布".into()),
            )
        });

        PublicPlanSavePesticideReferenceRow::new(
            300,
            10,
            20,
            Some("農薬A".into()),
            Some("成分".into()),
            Some("説明".into()),
            None,
            usage_constraint,
            application_detail,
        )
    }

    // Ruby: test "attributes_for_create uses row region when present"
    #[test]
    fn attributes_for_create_uses_row_region_when_present() {
        let row = build_row(false, false);
        let row_with_region = PublicPlanSavePesticideReferenceRow::new(
            row.reference_pesticide_id,
            row.reference_crop_id,
            row.reference_pest_id,
            row.name.clone(),
            row.active_ingredient.clone(),
            row.description.clone(),
            Some("us".into()),
            None,
            None,
        );

        let attrs = PlanSavePesticideAttributesMapper::attributes_for_create(
            &row_with_region,
            Some("jp"),
            101,
            201,
        );

        assert_eq!(attrs["region"].as_str(), Some("us"));
    }

    // Ruby: test "attributes_for_create resolves region from farm when row region is nil"
    #[test]
    fn attributes_for_create_resolves_region_from_farm_when_row_region_is_nil() {
        let row = build_row(false, false);

        let attrs = PlanSavePesticideAttributesMapper::attributes_for_create(
            &row,
            Some("jp"),
            101,
            201,
        );

        assert_eq!(attrs["crop_id"].as_i64(), Some(101));
        assert_eq!(attrs["pest_id"].as_i64(), Some(201));
        assert_eq!(attrs["name"].as_str(), Some("農薬A"));
        assert_eq!(attrs["active_ingredient"].as_str(), Some("成分"));
        assert_eq!(attrs["description"].as_str(), Some("説明"));
        assert_eq!(attrs["region"].as_str(), Some("jp"));
        assert_eq!(attrs["is_reference"].as_bool(), Some(false));
        assert_eq!(attrs["source_pesticide_id"].as_i64(), Some(300));
    }

    // Ruby: test "usage_constraint_attributes returns nil when row has no constraint"
    #[test]
    fn usage_constraint_attributes_returns_none_when_row_has_no_constraint() {
        assert!(PlanSavePesticideAttributesMapper::usage_constraint_attributes(&build_row(
            false,
            false
        ))
        .is_none());
    }

    // Ruby: test "usage_constraint_attributes maps nested row fields"
    #[test]
    fn usage_constraint_attributes_maps_nested_row_fields() {
        let row = build_row(true, false);

        let attrs = PlanSavePesticideAttributesMapper::usage_constraint_attributes(&row).unwrap();

        assert!((attrs["min_temperature"].as_f64().unwrap() - 5.0).abs() < 0.001);
        assert!((attrs["max_temperature"].as_f64().unwrap() - 35.0).abs() < 0.001);
        assert_eq!(attrs["max_application_count"].as_i64(), Some(2));
    }

    // Ruby: test "application_detail_attributes returns nil when row has no detail"
    #[test]
    fn application_detail_attributes_returns_none_when_row_has_no_detail() {
        assert!(PlanSavePesticideAttributesMapper::application_detail_attributes(&build_row(
            false,
            false
        ))
        .is_none());
    }

    // Ruby: test "application_detail_attributes maps nested row fields"
    #[test]
    fn application_detail_attributes_maps_nested_row_fields() {
        let row = build_row(false, true);

        let attrs = PlanSavePesticideAttributesMapper::application_detail_attributes(&row).unwrap();

        assert_eq!(attrs["dilution_ratio"].as_str(), Some("1000倍"));
        assert!((attrs["amount_per_m2"].as_f64().unwrap() - 0.5).abs() < 0.001);
        assert_eq!(attrs["amount_unit"].as_str(), Some("g"));
        assert_eq!(attrs["application_method"].as_str(), Some("散布"));
    }
}
