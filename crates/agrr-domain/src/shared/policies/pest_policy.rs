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
mod tests {
    use super::*;
    use crate::shared::attr::attr_map_from_pairs;
    use crate::shared::user::User;
    use crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListMode;

    fn user(id: i64, admin: bool) -> User {
        User::new(id, admin)
    }

    // Ruby: test "normalize_attrs_for_create for regular user forces non-reference"
    #[test]
    fn normalize_attrs_for_create_for_regular_user_forces_non_reference() {
        let regular = user(9, false);
        let h = normalize_attrs_for_create(
            &regular,
            attr_map_from_pairs([
                ("name", AttrValue::from("P")),
                ("is_reference", AttrValue::Bool(true)),
            ]),
            false,
        );
        assert_eq!(h.get("user_id"), Some(&AttrValue::Int(9)));
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(false)));
    }

    // Ruby: test "view_allowed? for reference pest"
    #[test]
    fn view_allowed_for_reference_pest() {
        let regular = user(9, false);
        assert!(view_allowed(&regular, true, None));
    }

    // Ruby: test "selectable_list_filter is reference_or_owned for regular user"
    #[test]
    fn selectable_list_filter_is_reference_or_owned_for_regular_user() {
        let regular = user(9, false);
        let filter = selectable_list_filter(&regular);
        assert_eq!(filter.mode, ReferenceIndexListMode::ReferenceOrOwned);
        assert_eq!(filter.user_id, 9);
    }

    // Ruby: test "selectable_for_user? allows reference and own pests"
    #[test]
    fn selectable_for_user_allows_reference_and_own_pests() {
        let regular = user(9, false);
        assert!(selectable_for_user(&regular, true, None));
        assert!(selectable_for_user(&regular, false, Some(9)));
        assert!(!selectable_for_user(&regular, false, Some(10)));
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
            false,
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
            false,
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
}
