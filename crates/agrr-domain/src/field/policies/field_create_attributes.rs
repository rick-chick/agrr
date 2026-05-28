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
mod tests {
    use super::*;
    use crate::shared::attr::attr_map_from_pairs;

    // Ruby: test "merge_for_build sets user_id and farm_id"
    #[test]
    fn merge_for_build_sets_user_id_and_farm_id() {
        let h = merge_for_build(
            1,
            2,
            attr_map_from_pairs([("name", AttrValue::from("A"))]),
        );
        assert_eq!(h.get("user_id"), Some(&AttrValue::Int(1)));
        assert_eq!(h.get("farm_id"), Some(&AttrValue::Int(2)));
        assert_eq!(h.get("name"), Some(&AttrValue::from("A")));
    }
}
