//! Ruby: `Domain::CultivationPlan::Mappers::PlanSaveFertilizeAttributesMapper`

use std::collections::BTreeMap;

use serde_json::{json, Value};

use crate::cultivation_plan::dtos::PublicPlanSaveFertilizeReferenceRow;

pub fn attributes_for_create(
    row: &PublicPlanSaveFertilizeReferenceRow,
    region: Option<&str>,
    name: &str,
) -> BTreeMap<String, Value> {
    BTreeMap::from([
        ("name".into(), json!(name)),
        ("n".into(), json!(row.n)),
        ("p".into(), json!(row.p)),
        ("k".into(), json!(row.k)),
        ("description".into(), json!(row.description)),
        ("package_size".into(), json!(row.package_size)),
        (
            "region".into(),
            json!(row
                .region
                .clone()
                .or_else(|| region.map(str::to_string))),
        ),
        ("is_reference".into(), json!(false)),
        ("source_fertilize_id".into(), json!(row.reference_fertilize_id)),
    ])
}
