//! Ruby: `Domain::CultivationPlan::Dtos::FieldCultivationOptimizationPersist`

use serde_json::{json, Map, Value};

use crate::weather_data::helpers::copy_and_deep_freeze;

/// Ruby: `Domain::CultivationPlan::Dtos::FieldCultivationOptimizationPersist`
#[derive(Debug, Clone)]
pub struct FieldCultivationOptimizationPersist {
    pub allocation_id: i64,
    pub expected_revenue: f64,
    pub profit: f64,
    raw_allocation_document: Option<Value>,
}

impl FieldCultivationOptimizationPersist {
    pub fn new(
        allocation_id: i64,
        expected_revenue: f64,
        profit: f64,
        raw_allocation_document: Value,
    ) -> Self {
        Self {
            allocation_id,
            expected_revenue,
            profit,
            raw_allocation_document: copy_and_deep_freeze(Some(raw_allocation_document)),
        }
    }

    pub fn raw_allocation_document(&self) -> Option<&Value> {
        self.raw_allocation_document.as_ref()
    }

    /// ActiveRecord serialize(JSON) 向けミュータブル Hash
    pub fn to_storage_hash(&self) -> Map<String, Value> {
        let mut map = Map::new();
        map.insert("allocation_id".into(), json!(self.allocation_id));
        map.insert("expected_revenue".into(), json!(self.expected_revenue));
        map.insert("profit".into(), json!(self.profit));
        map.insert(
            "raw".into(),
            copy_and_deep_freeze(self.raw_allocation_document.clone())
                .unwrap_or(Value::Null),
        );
        map
    }
}
