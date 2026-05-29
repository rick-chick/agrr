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

/// Bridges [`ReferenceRecordAccessFilter`] to crop policy functions.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CropRecordAccessPolicy;

impl RecordAccessPolicy for CropRecordAccessPolicy {
    fn view_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
        view_allowed(user, is_reference, record_user_id)
    }

    fn edit_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
        edit_allowed(user, is_reference, record_user_id)
    }
}

pub fn record_access_filter(user: User) -> ReferenceRecordAccessFilter<CropRecordAccessPolicy> {
    ReferenceRecordAccessFilter::new(user)
}

/// Ruby: `Domain::Shared::Policies::CropPolicy`
pub fn view_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
    user.admin || is_reference || record_user_id == Some(user.id)
}

pub fn edit_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
    user.admin || (!is_reference && record_user_id == Some(user.id))
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

fn str_present(value: Option<&str>) -> bool {
    value.map(|s| !s.trim().is_empty()).unwrap_or(false)
}

fn attr_id_as_i64(value: Option<i64>) -> i64 {
    value.unwrap_or(0)
}

/// 害虫との crop_pest 関連付け可否（ORM 非依存）。
pub fn crop_associable_with_pest(
    user: &User,
    crop_is_reference: bool,
    crop_user_id: Option<i64>,
    crop_region: Option<&str>,
    pest_is_reference: bool,
    pest_user_id: Option<i64>,
    pest_region: Option<&str>,
) -> bool {
    if str_present(pest_region) {
        let crop_region_s = crop_region.unwrap_or("");
        let pest_region_s = pest_region.unwrap_or("");
        if crop_region_s != pest_region_s {
            return false;
        }
    }

    if pest_is_reference {
        return crop_is_reference;
    }

    if crop_is_reference {
        return true;
    }

    let mut owner_id = pest_user_id;
    if owner_id.is_none() {
        let _ = user;
        owner_id = Some(user.id);
    }
    attr_id_as_i64(crop_user_id) == attr_id_as_i64(owner_id)
}

/// AI 害虫作成時の affected_crops: 参照作物は常に可。匿名は不可。
pub fn ai_affected_crop_linkable(
    user: Option<&User>,
    crop_is_reference: bool,
    crop_user_id: Option<i64>,
    crop_region: Option<&str>,
    pest_is_reference: bool,
    pest_user_id: Option<i64>,
    pest_region: Option<&str>,
) -> bool {
    if crop_is_reference {
        return true;
    }
    let Some(user) = user else {
        return false;
    };
    if user.anonymous {
        return false;
    }
    crop_associable_with_pest(
        user,
        crop_is_reference,
        crop_user_id,
        crop_region,
        pest_is_reference,
        pest_user_id,
        pest_region,
    )
}

#[cfg(test)]
mod policies_crop_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/policies_crop_policy_test.rs"));
}
