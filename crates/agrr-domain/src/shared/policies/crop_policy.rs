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
mod tests {
    use super::*;
    use crate::shared::attr::{attr_map_from_pairs, AttrValue};
    use crate::shared::user::User;

    fn user(id: i64, admin: bool) -> User {
        User::new(id, admin)
    }

    #[test]
    fn view_allowed_for_admin() {
        let admin = user(1, true);
        assert!(view_allowed(&admin, false, Some(999)));
    }

    #[test]
    fn view_allowed_for_reference_crop() {
        let regular = user(9, false);
        assert!(view_allowed(&regular, true, None));
    }

    #[test]
    fn view_allowed_for_own_crop() {
        let regular = user(9, false);
        assert!(view_allowed(&regular, false, Some(9)));
    }

    #[test]
    fn view_allowed_denies_other_user_non_reference_crop() {
        let regular = user(9, false);
        assert!(!view_allowed(&regular, false, Some(999)));
    }

    #[test]
    fn edit_allowed_for_own_non_reference() {
        let regular = user(9, false);
        assert!(edit_allowed(&regular, false, Some(9)));
    }

    // Ruby: test "normalize_attrs_for_create for admin with reference crop"
    #[test]
    fn normalize_attrs_for_create_admin_reference_crop() {
        let admin = user(1, true);
        let h = normalize_attrs_for_create(
            &admin,
            attr_map_from_pairs([
                ("name", AttrValue::from("RefCrop")),
                ("is_reference", AttrValue::Bool(true)),
            ]),
        );
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(true)));
        assert_eq!(h.get("user_id"), Some(&AttrValue::Null));
        assert_eq!(h.get("name"), Some(&AttrValue::from("RefCrop")));
    }

    // Ruby: test "normalize_attrs_for_create for admin with user crop (non-reference)"
    #[test]
    fn normalize_attrs_for_create_admin_user_crop() {
        let admin = user(1, true);
        let h = normalize_attrs_for_create(
            &admin,
            attr_map_from_pairs([
                ("name", AttrValue::from("UserCrop")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        );
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(false)));
        assert_eq!(h.get("user_id"), Some(&AttrValue::Int(1)));
        assert_eq!(h.get("name"), Some(&AttrValue::from("UserCrop")));
    }

    // Ruby: test "normalize_attrs_for_create for regular user always creates non-reference crop owned by user"
    #[test]
    fn normalize_attrs_for_create_regular_user_forces_owned_non_reference() {
        let regular = user(9, false);
        let h = normalize_attrs_for_create(
            &regular,
            attr_map_from_pairs([
                ("name", AttrValue::from("UserCrop")),
                ("is_reference", AttrValue::Bool(true)),
            ]),
        );
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(false)));
        assert_eq!(h.get("user_id"), Some(&AttrValue::Int(9)));
        assert_eq!(h.get("name"), Some(&AttrValue::from("UserCrop")));
    }

    // Ruby: test "normalize_attrs_for_create は admin の region を保持する"
    #[test]
    fn normalize_attrs_for_create_admin_keeps_region() {
        let admin = user(1, true);
        let h = normalize_attrs_for_create(
            &admin,
            attr_map_from_pairs([
                ("region", AttrValue::from("us")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        );
        assert_eq!(h.get("region"), Some(&AttrValue::from("us")));
    }

    // Ruby: test "normalize_attrs_for_create は一般ユーザーの region を破棄する"
    #[test]
    fn normalize_attrs_for_create_regular_user_strips_region() {
        let regular = user(9, false);
        let h = normalize_attrs_for_create(
            &regular,
            attr_map_from_pairs([
                ("region", AttrValue::from("us")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        );
        assert!(!h.contains_key("region"));
    }

    // Ruby: test "normalize_attrs_for_update は admin の region を保持する"
    #[test]
    fn normalize_attrs_for_update_admin_keeps_region() {
        let admin = user(1, true);
        let h = normalize_attrs_for_update(
            &admin,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(false))]),
            attr_map_from_pairs([("region", AttrValue::from("in"))]),
        );
        assert_eq!(h.get("region"), Some(&AttrValue::from("in")));
    }

    // Ruby: test "normalize_attrs_for_update は一般ユーザーの region を破棄する"
    #[test]
    fn normalize_attrs_for_update_regular_user_strips_region() {
        let regular = user(9, false);
        let h = normalize_attrs_for_update(
            &regular,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(false))]),
            attr_map_from_pairs([("region", AttrValue::from("us"))]),
        );
        assert!(!h.contains_key("region"));
    }

    // Ruby: test "crop_associable_with_pest? matches reference and ownership rules"
    #[test]
    fn crop_associable_with_pest_matches_reference_and_ownership_rules() {
        let user = user(1, false);

        assert!(crop_associable_with_pest(
            &user, true, None, None, true, None, None,
        ));

        assert!(!crop_associable_with_pest(
            &user, false, Some(1), None, true, None, None,
        ));

        assert!(crop_associable_with_pest(
            &user, true, None, None, false, Some(1), None,
        ));

        assert!(crop_associable_with_pest(
            &user, false, Some(2), None, false, Some(2), None,
        ));
    }

    // Ruby: test "region mismatch denies"
    #[test]
    fn crop_associable_with_pest_region_mismatch_denies() {
        let user = user(1, false);
        assert!(!crop_associable_with_pest(
            &user, true, None, Some("us"), true, None, Some("jp"),
        ));
    }

    // Ruby: test "ai_affected_crop_linkable? allows reference crop for anonymous user path"
    #[test]
    fn ai_affected_crop_linkable_allows_reference_crop() {
        let user = user(1, false);
        assert!(ai_affected_crop_linkable(
            Some(&user),
            true,
            None,
            None,
            false,
            Some(1),
            None,
        ));
    }
}
