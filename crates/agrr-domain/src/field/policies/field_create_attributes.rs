use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};

/// Ruby: `Domain::Field::Policies::FieldCreateAttributes`
pub fn merge_for_build(user_id: i64, farm_id: i64, attrs: AttrMap) -> AttrMap {
    let mut h = attrs;
    if !h.contains_key("user_id") {
        h.insert("user_id".into(), AttrValue::Int(user_id));
    }
    h.insert("farm_id".into(), AttrValue::Int(farm_id));
    h
}

#[cfg(test)]
mod policies_field_create_attributes_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field/policies_field_create_attributes_test.rs"));
}
