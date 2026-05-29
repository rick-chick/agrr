use crate::shared::attr::{AttrMap, AttrValue};
use crate::shared::reference_record_access_filter::{
    RecordAccessPolicy, ReferenceRecordAccessFilter,
};
use crate::shared::type_converters::cast_boolean_attr;
use crate::shared::user::User;
use crate::shared::value_objects::reference_index_list_filter::{
    ReferenceIndexListFilter, ReferenceIndexListMode,
};

/// Bridges [`ReferenceRecordAccessFilter`] to interaction rule policy functions.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct InteractionRuleRecordAccessPolicy;

impl RecordAccessPolicy for InteractionRuleRecordAccessPolicy {
    fn view_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
        view_allowed(user, is_reference, record_user_id)
    }

    fn edit_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
        edit_allowed(user, is_reference, record_user_id)
    }
}

pub fn record_access_filter(
    user: User,
) -> ReferenceRecordAccessFilter<InteractionRuleRecordAccessPolicy> {
    ReferenceRecordAccessFilter::new(user)
}

/// Ruby: `Domain::Shared::Policies::InteractionRulePolicy`
pub fn view_allowed(user: &User, is_reference: bool, user_id: Option<i64>) -> bool {
    let _ = is_reference;
    user.admin || user_id == Some(user.id)
}

pub fn edit_allowed(user: &User, is_reference: bool, user_id: Option<i64>) -> bool {
    user.admin || (!is_reference && user_id == Some(user.id))
}

pub fn index_list_filter(user: &User) -> ReferenceIndexListFilter {
    let mode = if user.admin {
        ReferenceIndexListMode::ReferenceOrOwned
    } else {
        ReferenceIndexListMode::OwnedNonReference
    };
    ReferenceIndexListFilter::new(mode, user.id)
}

pub fn normalize_attrs_for_create(user: &User, params: AttrMap) -> AttrMap {
    let mut attributes = params;

    if !user.admin {
        attributes.remove("region");
    }

    let is_reference = attributes
        .get("is_reference")
        .map(cast_boolean_attr)
        .unwrap_or(false);

    if is_reference {
        attributes.insert("user_id".into(), AttrValue::Null);
        attributes.insert("is_reference".into(), AttrValue::Bool(true));
    } else {
        if !attributes.contains_key("user_id") {
            attributes.insert("user_id".into(), AttrValue::Int(user.id));
        }
        if attributes.get("is_reference").is_none() {
            attributes.insert("is_reference".into(), AttrValue::Bool(false));
        }
    }

    attributes
}

pub fn normalize_attrs_for_update(
    user: &User,
    current_attrs: AttrMap,
    params: AttrMap,
) -> AttrMap {
    let rule = current_attrs;
    let mut update_params = params;

    if !user.admin {
        update_params.remove("region");
    }

    if let Some(is_ref_val) = update_params.get("is_reference") {
        let requested_reference = cast_boolean_attr(is_ref_val);
        let current_reference = rule
            .get("is_reference")
            .map(cast_boolean_attr)
            .unwrap_or(false);

        if requested_reference != current_reference {
            if requested_reference {
                update_params.insert("user_id".into(), AttrValue::Null);
            } else {
                update_params.insert("user_id".into(), AttrValue::Int(user.id));
            }
        }
    }

    update_params
}

#[cfg(test)]
mod policies_interaction_rule_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/policies_interaction_rule_policy_test.rs"));
}
