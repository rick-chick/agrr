use crate::shared::attr::{AttrMap, AttrValue};
use crate::shared::type_converters::cast_boolean_attr;
use crate::shared::user::User;

/// Ruby: `Domain::Shared::Policies::ReferencableResourcePolicy`
pub fn visible_for_user(user: &User, is_reference: bool, user_id: Option<i64>) -> bool {
    if user.admin {
        is_reference || user_id == Some(user.id)
    } else {
        !is_reference && user_id == Some(user.id)
    }
}

pub fn reference_record_user_id_valid(is_reference: bool, user_id: Option<i64>) -> bool {
    if is_reference {
        user_id.is_none()
    } else {
        user_id.is_some()
    }
}

pub fn reference_assignment_allowed(user: &User, is_reference: bool) -> bool {
    !is_reference || user.admin
}

pub fn reference_flag_change_allowed(user: &User, requested: bool, current: bool) -> bool {
    requested == current || user.admin
}

pub fn duplicate_name_record(existing_id: Option<i64>, exclude_id: Option<i64>) -> bool {
    match existing_id {
        None => false,
        Some(id) => exclude_id.map(|ex| id != ex).unwrap_or(true),
    }
}

/// Ruby: `normalize_referencable_attrs_for_create`
pub fn normalize_referencable_attrs_for_create(
    user: &User,
    attrs: AttrMap,
    admin_forced: bool,
) -> AttrMap {
    let mut h = attrs;
    let privileged = user.admin || admin_forced;

    if !privileged {
        h.remove("region");
    }

    let is_reference = h
        .get("is_reference")
        .map(cast_boolean_attr)
        .unwrap_or(false);

    if privileged {
        if is_reference {
            h.insert("user_id".into(), AttrValue::Null);
            h.insert("is_reference".into(), AttrValue::Bool(true));
        } else {
            if !h.contains_key("user_id") {
                h.insert("user_id".into(), AttrValue::Int(user.id));
            }
            h.insert("is_reference".into(), AttrValue::Bool(false));
        }
    } else {
        h.insert("user_id".into(), AttrValue::Int(user.id));
        h.insert("is_reference".into(), AttrValue::Bool(false));
    }

    h
}

/// Ruby: `normalize_referencable_attrs_for_update`
pub fn normalize_referencable_attrs_for_update(
    user: &User,
    current_attrs: AttrMap,
    requested_attrs: AttrMap,
) -> AttrMap {
    let current = current_attrs;
    let mut attributes = requested_attrs;

    if !user.admin {
        attributes.remove("region");
    }

    if let Some(is_ref_val) = attributes.get("is_reference") {
        let mut requested_reference = cast_boolean_attr(is_ref_val);
        let current_reference = current
            .get("is_reference")
            .map(cast_boolean_attr)
            .unwrap_or(false);

        if let AttrValue::Null = is_ref_val {
            requested_reference = false;
        }

        if requested_reference != current_reference {
            if requested_reference {
                attributes.insert("user_id".into(), AttrValue::Null);
            } else {
                attributes.insert("user_id".into(), AttrValue::Int(user.id));
            }
            attributes.insert("is_reference".into(), AttrValue::Bool(requested_reference));
        } else {
            attributes.remove("is_reference");
        }
    }

    attributes
}

#[cfg(test)]
mod policies_referencable_resource_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/policies_referencable_resource_policy_test.rs"));
}
