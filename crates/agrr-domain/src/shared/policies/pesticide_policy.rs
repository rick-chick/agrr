use crate::shared::attr::AttrMap;
use crate::shared::policies::referencable_resource_policy::{
    normalize_referencable_attrs_for_create, normalize_referencable_attrs_for_update,
    visible_for_user,
};
use crate::shared::reference_record_access_filter::{
    RecordAccessPolicy, ReferenceRecordAccessFilter,
};
use crate::shared::user::User;
use crate::shared::value_objects::reference_index_list_filter::{
    ReferenceIndexListFilter, ReferenceIndexListMode,
};

/// Bridges [`ReferenceRecordAccessFilter`] to pesticide policy functions.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PesticideRecordAccessPolicy;

impl RecordAccessPolicy for PesticideRecordAccessPolicy {
    fn view_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
        view_allowed(user, is_reference, record_user_id)
    }

    fn edit_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
        edit_allowed(user, is_reference, record_user_id)
    }
}

pub fn record_access_filter(
    user: User,
) -> ReferenceRecordAccessFilter<PesticideRecordAccessPolicy> {
    ReferenceRecordAccessFilter::new(user)
}

/// Ruby: `Domain::Shared::Policies::PesticidePolicy`
pub fn view_allowed(user: &User, is_reference: bool, user_id: Option<i64>) -> bool {
    visible_for_user(user, is_reference, user_id)
}

pub fn edit_allowed(user: &User, is_reference: bool, user_id: Option<i64>) -> bool {
    view_allowed(user, is_reference, user_id)
}

pub fn index_list_filter(user: &User) -> ReferenceIndexListFilter {
    let mode = if user.admin {
        ReferenceIndexListMode::ReferenceOrOwned
    } else {
        ReferenceIndexListMode::OwnedNonReference
    };
    ReferenceIndexListFilter::new(mode, user.id)
}

pub fn masters_crop_pesticides_index_filter(user: &User) -> ReferenceIndexListFilter {
    ReferenceIndexListFilter::new(ReferenceIndexListMode::ReferenceOrOwned, user.id)
}

pub fn normalize_attrs_for_create(user: &User, attrs: AttrMap) -> AttrMap {
    normalize_referencable_attrs_for_create(user, attrs, false)
}

pub fn normalize_attrs_for_update(
    user: &User,
    current_attrs: AttrMap,
    requested_attrs: AttrMap,
) -> AttrMap {
    normalize_referencable_attrs_for_update(user, current_attrs, requested_attrs)
}

#[cfg(test)]
mod policies_pesticide_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/policies_pesticide_policy_test.rs"));
}
