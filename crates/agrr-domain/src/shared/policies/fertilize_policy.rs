use crate::shared::attr::AttrMap;
use crate::shared::policies::referencable_resource_policy::{
    normalize_referencable_attrs_for_create, normalize_referencable_attrs_for_update,
};
use crate::shared::reference_record_access_filter::{
    RecordAccessPolicy, ReferenceRecordAccessFilter,
};
use crate::shared::user::User;
use crate::shared::value_objects::reference_index_list_filter::{
    ReferenceIndexListFilter, ReferenceIndexListMode,
};

/// Bridges [`ReferenceRecordAccessFilter`] to fertilize policy functions.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FertilizeRecordAccessPolicy;

impl RecordAccessPolicy for FertilizeRecordAccessPolicy {
    fn view_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
        view_allowed(user, is_reference, record_user_id)
    }

    fn edit_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
        edit_allowed(user, is_reference, record_user_id)
    }
}

pub fn record_access_filter(user: User) -> ReferenceRecordAccessFilter<FertilizeRecordAccessPolicy> {
    ReferenceRecordAccessFilter::new(user)
}

/// Ruby: `Domain::Shared::Policies::FertilizePolicy`
pub fn view_allowed(user: &User, is_reference: bool, user_id: Option<i64>) -> bool {
    if user.admin {
        return true;
    }
    user_id == Some(user.id) && !is_reference
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
mod policies_fertilize_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/policies_fertilize_policy_test.rs"));
}
