//! Ruby: `Domain::CultivationPlan::Mappers::PlanSavePestAttributesMapper`

use std::collections::BTreeMap;

use serde_json::{json, Value};

use crate::cultivation_plan::dtos::PublicPlanSavePestReferenceRow;

pub fn attributes_for_create(
    row: &PublicPlanSavePestReferenceRow,
    region: Option<&str>,
) -> BTreeMap<String, Value> {
    BTreeMap::from([
        ("name".into(), json!(row.name)),
        ("name_scientific".into(), json!(row.name_scientific)),
        ("family".into(), json!(row.family)),
        ("order".into(), json!(row.order)),
        ("description".into(), json!(row.description)),
        ("occurrence_season".into(), json!(row.occurrence_season)),
        (
            "region".into(),
            json!(row
                .region
                .clone()
                .or_else(|| region.map(str::to_string))),
        ),
        ("is_reference".into(), json!(false)),
        ("source_pest_id".into(), json!(row.reference_pest_id)),
    ])
}
