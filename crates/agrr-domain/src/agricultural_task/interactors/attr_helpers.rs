use crate::shared::attr::{AttrMap, AttrValue};
use crate::shared::type_converters::cast_boolean_attr;

pub(crate) fn attr_is_reference(map: &AttrMap) -> bool {
    map.get("is_reference")
        .map(cast_boolean_attr)
        .unwrap_or(false)
}

pub(crate) fn attr_user_id(map: &AttrMap) -> Option<i64> {
    match map.get("user_id") {
        Some(AttrValue::Int(id)) => Some(*id),
        Some(AttrValue::Null) | None => None,
        _ => None,
    }
}

pub(crate) fn attr_name(map: &AttrMap) -> Option<String> {
    map.get("name").and_then(|v| match v {
        AttrValue::Str(s) => Some(s.clone()),
        _ => None,
    })
}

pub(crate) fn str_present(value: &Option<String>) -> bool {
    value.as_ref().is_some_and(|s| !s.trim().is_empty())
}
