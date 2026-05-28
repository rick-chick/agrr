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
mod tests {
    use super::*;
    use crate::shared::attr::attr_map_from_pairs;
    use crate::shared::user::User;

    fn user(id: i64, admin: bool) -> User {
        User::new(id, admin)
    }

    // Ruby: test "normalize_attrs_for_create は admin の region を保持する"
    #[test]
    fn normalize_attrs_for_create_admin_keeps_region() {
        let admin = user(1, true);
        let h = normalize_attrs_for_create(
            &admin,
            attr_map_from_pairs([
                ("rule_type", AttrValue::from("continuous_cultivation")),
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
                ("rule_type", AttrValue::from("continuous_cultivation")),
                ("region", AttrValue::from("us")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        );
        assert!(!h.contains_key("region"));
    }

    // Ruby: test "normalize_attrs_for_create は参照ルールを user_id=nil にする"
    #[test]
    fn normalize_attrs_for_create_reference_rule_sets_user_id_null() {
        let admin = user(1, true);
        let h = normalize_attrs_for_create(
            &admin,
            attr_map_from_pairs([
                ("rule_type", AttrValue::from("continuous_cultivation")),
                ("is_reference", AttrValue::Bool(true)),
            ]),
        );
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(true)));
        assert_eq!(h.get("user_id"), Some(&AttrValue::Null));
    }

    // Ruby: test "normalize_attrs_for_create は非参照ルールを呼び出しユーザー所有にする"
    #[test]
    fn normalize_attrs_for_create_non_reference_rule_owned_by_caller() {
        let regular = user(9, false);
        let h = normalize_attrs_for_create(
            &regular,
            attr_map_from_pairs([
                ("rule_type", AttrValue::from("continuous_cultivation")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        );
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(false)));
        assert_eq!(h.get("user_id"), Some(&AttrValue::Int(9)));
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

    // Ruby: test "normalize_attrs_for_update は参照化のとき user_id を nil にする"
    #[test]
    fn normalize_attrs_for_update_reference_sets_user_id_null() {
        let admin = user(1, true);
        let h = normalize_attrs_for_update(
            &admin,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(false))]),
            attr_map_from_pairs([("is_reference", AttrValue::Bool(true))]),
        );
        assert_eq!(h.get("user_id"), Some(&AttrValue::Null));
    }

    // Ruby: test "normalize_attrs_for_update は参照解除のとき user_id を操作ユーザーにする"
    #[test]
    fn normalize_attrs_for_update_dereference_sets_user_id_to_operator() {
        let admin = user(1, true);
        let h = normalize_attrs_for_update(
            &admin,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(true))]),
            attr_map_from_pairs([("is_reference", AttrValue::Bool(false))]),
        );
        assert_eq!(h.get("user_id"), Some(&AttrValue::Int(1)));
    }

    // Ruby: test "view_allowed? は admin と所有者に許可する"
    #[test]
    fn view_allowed_for_admin_and_owner() {
        let admin = user(1, true);
        let regular = user(9, false);
        assert!(view_allowed(&admin, false, Some(999)));
        assert!(view_allowed(&regular, false, Some(9)));
        assert!(!view_allowed(&regular, false, Some(999)));
    }

    // Ruby: test "edit_allowed? は一般ユーザーの参照ルール編集を拒否する"
    #[test]
    fn edit_allowed_denies_reference_for_regular_user() {
        let admin = user(1, true);
        let regular = user(9, false);
        assert!(edit_allowed(&admin, true, None));
        assert!(!edit_allowed(&regular, true, None));
        assert!(edit_allowed(&regular, false, Some(9)));
    }
}
