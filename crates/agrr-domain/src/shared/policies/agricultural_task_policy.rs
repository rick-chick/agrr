use crate::shared::attr::AttrMap;
use crate::shared::policies::referencable_resource_policy::{
    normalize_referencable_attrs_for_create, normalize_referencable_attrs_for_update,
};
use crate::shared::reference_record_access_filter::{
    RecordAccessPolicy, ReferenceRecordAccessFilter,
};
use crate::shared::user::User;

/// Bridges [`ReferenceRecordAccessFilter`] to agricultural task policy functions.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AgriculturalTaskRecordAccessPolicy;

impl RecordAccessPolicy for AgriculturalTaskRecordAccessPolicy {
    fn view_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
        view_allowed(user, is_reference, record_user_id)
    }

    fn edit_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
        edit_allowed(user, is_reference, record_user_id)
    }
}

pub fn record_access_filter(user: User) -> ReferenceRecordAccessFilter<AgriculturalTaskRecordAccessPolicy> {
    ReferenceRecordAccessFilter::new(user)
}

/// Ruby: `Domain::Shared::Policies::AgriculturalTaskPolicy`
pub fn view_allowed(user: &User, is_reference: bool, user_id: Option<i64>) -> bool {
    user.admin || is_reference || user_id == Some(user.id)
}

/// マスター API: 作物に紐付ける農業タスクは参照タスクまたは自ユーザーのタスクのみ
pub fn masters_crop_task_template_associate_allowed(
    user: &User,
    is_reference: bool,
    user_id: Option<i64>,
) -> bool {
    let _ = user;
    is_reference || user_id == Some(user.id)
}

pub fn edit_allowed(user: &User, is_reference: bool, user_id: Option<i64>) -> bool {
    user.admin || (!is_reference && user_id == Some(user.id))
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
mod tests {
    use super::*;
    use crate::shared::attr::{attr_map_from_pairs, AttrValue};
    use crate::shared::user::User;

    fn user(id: i64, admin: bool) -> User {
        User::new(id, admin)
    }

    // Ruby: test "normalize_attrs_for_create for regular user"
    #[test]
    fn normalize_attrs_for_create_for_regular_user() {
        let regular = user(9, false);
        let h = normalize_attrs_for_create(
            &regular,
            attr_map_from_pairs([
                ("name", AttrValue::from("T")),
                ("is_reference", AttrValue::Bool(false)),
            ]),
        );
        assert_eq!(h.get("user_id"), Some(&AttrValue::Int(9)));
        assert_eq!(h.get("is_reference"), Some(&AttrValue::Bool(false)));
    }

    // Ruby: test "masters_crop_task_template_associate_allowed? allows reference task for another owner"
    #[test]
    fn masters_crop_task_template_associate_allowed_allows_reference_task_for_another_owner() {
        let regular = user(9, false);
        assert!(masters_crop_task_template_associate_allowed(
            &regular,
            true,
            Some(99)
        ));
    }

    // Ruby: test "masters_crop_task_template_associate_allowed? allows own non-reference task"
    #[test]
    fn masters_crop_task_template_associate_allowed_allows_own_non_reference_task() {
        let regular = user(9, false);
        assert!(masters_crop_task_template_associate_allowed(
            &regular,
            false,
            Some(9)
        ));
    }

    // Ruby: test "masters_crop_task_template_associate_allowed? rejects other user non-reference task"
    #[test]
    fn masters_crop_task_template_associate_allowed_rejects_other_user_non_reference_task() {
        let regular = user(9, false);
        assert!(!masters_crop_task_template_associate_allowed(
            &regular,
            false,
            Some(99)
        ));
    }

    // Ruby: test "view_allowed? for own task"
    #[test]
    fn view_allowed_for_own_task() {
        let regular = user(9, false);
        assert!(view_allowed(&regular, false, Some(9)));
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
}
