use crate::shared::attr::AttrMap;
use crate::shared::attr::AttrValue;
use crate::shared::reference_record_access_filter::{
    RecordAccessPolicy, ReferenceRecordAccessFilter,
};
use crate::shared::user::User;

/// Bridges [`ReferenceRecordAccessFilter`] to farm policy functions.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FarmRecordAccessPolicy;

impl RecordAccessPolicy for FarmRecordAccessPolicy {
    fn view_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
        view_allowed(user, is_reference, record_user_id)
    }

    fn edit_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
        edit_allowed(user, is_reference, record_user_id)
    }
}

pub fn record_access_filter(user: User) -> ReferenceRecordAccessFilter<FarmRecordAccessPolicy> {
    ReferenceRecordAccessFilter::new(user)
}

/// Ruby: `Domain::Shared::Policies::FarmPolicy`
pub fn view_allowed(user: &User, is_reference: bool, user_id: Option<i64>) -> bool {
    user.admin || is_reference || user_id == Some(user.id)
}

/// 所有農場（非参照かつ自分のもの）または管理者
pub fn owned_visible(user: &User, is_reference: bool, user_id: Option<i64>) -> bool {
    user.admin || (!is_reference && user_id == Some(user.id))
}

pub fn edit_allowed(user: &User, is_reference: bool, user_id: Option<i64>) -> bool {
    user.admin || (!is_reference && user_id == Some(user.id))
}

pub fn normalize_attrs_for_create(user: &User, attrs: AttrMap) -> AttrMap {
    let mut h = attrs;
    if !user.admin {
        h.remove("region");
    }
    h.insert("user_id".into(), AttrValue::Int(user.id));
    h.insert("is_reference".into(), AttrValue::Bool(false));
    h
}

pub fn normalize_attrs_for_update(
    user: &User,
    _current_attrs: AttrMap,
    requested_attrs: AttrMap,
) -> AttrMap {
    let mut attributes = requested_attrs;
    if !user.admin {
        attributes.remove("region");
    }
    attributes
}

#[cfg(test)]
mod policies_farm_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/policies_farm_policy_test.rs"));
}
