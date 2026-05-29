//! Ruby: `Domain::CultivationPlan::Mappers::PlanSaveFieldCreateAttributesMapper`

use std::collections::BTreeMap;

use serde_json::{json, Value};

use crate::cultivation_plan::dtos::PublicPlanSaveFieldDatum;

pub trait PlanSaveFieldTranslator {
    fn coordinates_message(&self, lat: f64, lng: f64) -> String;
}

pub fn attributes_for_create(
    datum: &PublicPlanSaveFieldDatum,
    translator: &dyn PlanSaveFieldTranslator,
) -> BTreeMap<String, Value> {
    let mut attrs = BTreeMap::from([
        ("name".into(), json!(datum.name)),
        ("area".into(), json!(datum.area)),
    ]);

    if datum.coordinates.len() >= 2 {
        attrs.insert(
            "description".into(),
            json!(translator.coordinates_message(
                datum.coordinates[0],
                datum.coordinates[1]
            )),
        );
    }

    attrs
}

#[cfg(test)]
mod mappers_plan_save_field_create_attributes_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/mappers_plan_save_field_create_attributes_mapper_test.rs"));
}
