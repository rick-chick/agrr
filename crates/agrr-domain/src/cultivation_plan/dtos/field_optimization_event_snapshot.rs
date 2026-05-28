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
mod tests {
    use super::*;

    // Ruby: test "to_h preserves cable shape"
    #[test]
    fn to_h_preserves_cable_shape() {
        let dto = FieldOptimizationEventSnapshot::new(7, 7, "North", 120.5);
        let h = dto.to_h();
        assert_eq!(h.get("id").and_then(|v| v.as_i64()), Some(7));
        assert_eq!(h.get("field_id").and_then(|v| v.as_i64()), Some(7));
        assert_eq!(h.get("name").and_then(|v| v.as_str()), Some("North"));
        assert!((h.get("area").and_then(|v| v.as_f64()).unwrap() - 120.5).abs() < 0.001);
    }
}
