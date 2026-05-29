use crate::shared::attr::{AttrMap, AttrValue};
use crate::shared::policies::referencable_resource_policy::normalize_referencable_attrs_for_create;
use crate::shared::reference_record_access_filter::{
    RecordAccessPolicy, ReferenceRecordAccessFilter,
};
use crate::shared::type_converters::cast_boolean_attr;
use crate::shared::user::User;
use crate::shared::value_objects::reference_index_list_filter::{
    ReferenceIndexListFilter, ReferenceIndexListMode,
};

/// Bridges [`ReferenceRecordAccessFilter`] to pest policy functions.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PestRecordAccessPolicy;

impl RecordAccessPolicy for PestRecordAccessPolicy {
    fn view_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
        view_allowed(user, is_reference, record_user_id)
    }

    fn edit_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
        edit_allowed(user, is_reference, record_user_id)
    }
}

pub fn record_access_filter(user: User) -> ReferenceRecordAccessFilter<PestRecordAccessPolicy> {
    ReferenceRecordAccessFilter::new(user)
}

/// Ruby: `Domain::Shared::Policies::PestPolicy`
pub fn index_list_filter(user: &User) -> ReferenceIndexListFilter {
    let mode = if user.admin {
        ReferenceIndexListMode::ReferenceOrOwned
    } else {
        ReferenceIndexListMode::OwnedNonReference
    };
    ReferenceIndexListFilter::new(mode, user.id)
}

pub fn selectable_list_filter(user: &User) -> ReferenceIndexListFilter {
    ReferenceIndexListFilter::new(ReferenceIndexListMode::ReferenceOrOwned, user.id)
}

pub fn selectable_for_user(user: &User, is_reference: bool, user_id: Option<i64>) -> bool {
    is_reference || user_id.unwrap_or(0) == user.id
}

pub fn view_allowed(user: &User, is_reference: bool, user_id: Option<i64>) -> bool {
    let _ = user;
    is_reference || user_id == Some(user.id)
}

pub fn edit_allowed(user: &User, is_reference: bool, user_id: Option<i64>) -> bool {
    if user.admin {
        is_reference || user_id == Some(user.id)
    } else {
        !is_reference && user_id == Some(user.id)
    }
}

pub fn normalize_attrs_for_create(user: &User, attrs: AttrMap, admin_forced: bool) -> AttrMap {
    normalize_referencable_attrs_for_create(user, attrs, admin_forced)
}

pub fn normalize_attrs_for_update(
    user: &User,
    current_attrs: AttrMap,
    requested_attrs: AttrMap,
) -> AttrMap {
    let pest = current_attrs;
    let mut attributes = requested_attrs;

    if !user.admin {
        attributes.remove("region");
    }

    if let Some(is_ref_val) = attributes.get("is_reference") {
        let requested_reference = cast_boolean_attr(is_ref_val);
        let current_reference = pest
            .get("is_reference")
            .map(cast_boolean_attr)
            .unwrap_or(false);

        if requested_reference != current_reference {
            if requested_reference {
                attributes.insert("user_id".into(), AttrValue::Null);
            } else {
                attributes.insert("user_id".into(), AttrValue::Int(user.id));
            }
        }
    }

    attributes
}

#[cfg(test)]
mod policies_pest_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/policies_pest_policy_test.rs"));
}
