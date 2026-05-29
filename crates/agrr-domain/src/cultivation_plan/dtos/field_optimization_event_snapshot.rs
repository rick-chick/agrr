//! Ruby: `Domain::CultivationPlan::Dtos::FieldOptimizationEventSnapshot`

use std::collections::BTreeMap;

use serde_json::{json, Value};

/// Ruby: `Domain::CultivationPlan::Dtos::FieldOptimizationEventSnapshot`
#[derive(Debug, Clone, PartialEq)]
pub struct FieldOptimizationEventSnapshot {
    pub id: i64,
    pub field_id: i64,
    pub name: String,
    pub area: f64,
}

impl FieldOptimizationEventSnapshot {
    pub fn new(id: i64, field_id: i64, name: impl Into<String>, area: f64) -> Self {
        Self {
            id,
            field_id,
            name: name.into(),
            area,
        }
    }

    pub fn to_h(&self) -> BTreeMap<String, Value> {
        BTreeMap::from([
            ("id".into(), json!(self.id)),
            ("field_id".into(), json!(self.field_id)),
            ("name".into(), json!(self.name)),
            ("area".into(), json!(self.area)),
        ])
    }
}

#[cfg(test)]
mod dtos_field_optimization_event_snapshot_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/dtos_field_optimization_event_snapshot_test.rs"));
}
