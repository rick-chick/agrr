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
mod tests {
    use super::*;
    use crate::shared::attr::attr_map_from_pairs;
    use crate::shared::user::User;

    fn user(id: i64, admin: bool) -> User {
        User::new(id, admin)
    }

    // Ruby: test "normalize_attrs_for_create sets user and non-reference"
    #[test]
    fn normalize_attrs_for_create_sets_user_and_non_reference() {
        let regular = user(9, false);
        let h = normalize_attrs_for_create(
            &regular,
            attr_map_from_pairs([
                ("name", AttrValue::from("F")),
                ("region", AttrValue::from("jp")),
            ]),
        );
        assert_eq!(h.get("user_id"), Some(&AttrValue::Int(9)));
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(false)));
        assert_eq!(h.get("name"), Some(&AttrValue::from("F")));
    }

    // Ruby: test "view_allowed? for admin"
    #[test]
    fn view_allowed_for_admin() {
        let admin = user(1, true);
        assert!(view_allowed(&admin, false, Some(999)));
    }

    // Ruby: test "view_allowed? for reference farm"
    #[test]
    fn view_allowed_for_reference_farm() {
        let regular = user(9, false);
        assert!(view_allowed(&regular, true, None));
    }

    // Ruby: test "edit_allowed? for own non-reference"
    #[test]
    fn edit_allowed_for_own_non_reference() {
        let regular = user(9, false);
        assert!(edit_allowed(&regular, false, Some(9)));
    }

    // Ruby: test "normalize_attrs_for_create は admin の region を保持する"
    #[test]
    fn normalize_attrs_for_create_admin_keeps_region() {
        let admin = user(1, true);
        let h = normalize_attrs_for_create(
            &admin,
            attr_map_from_pairs([
                ("name", AttrValue::from("F")),
                ("region", AttrValue::from("us")),
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
                ("name", AttrValue::from("F")),
                ("region", AttrValue::from("us")),
            ]),
        );
        assert!(!h.contains_key("region"));
    }

    // Ruby: test "normalize_attrs_for_update は admin の region を保持する"
    #[test]
    fn normalize_attrs_for_update_admin_keeps_region() {
        let admin = user(1, true);
        let h = normalize_attrs_for_update(&admin, AttrMap::new(), attr_map_from_pairs([(
            "region",
            AttrValue::from("in"),
        )]));
        assert_eq!(h.get("region"), Some(&AttrValue::from("in")));
    }

    // Ruby: test "normalize_attrs_for_update は一般ユーザーの region を破棄する"
    #[test]
    fn normalize_attrs_for_update_regular_user_strips_region() {
        let regular = user(9, false);
        let h = normalize_attrs_for_update(&regular, AttrMap::new(), attr_map_from_pairs([(
            "region",
            AttrValue::from("us"),
        )]));
        assert!(!h.contains_key("region"));
    }
}
