use std::marker::PhantomData;

use crate::shared::org_scope::organization_member_access;
use crate::shared::user::User;

/// Policy module bound to [`ReferenceRecordAccessFilter`] (Ruby: `policy_module` class).
pub trait RecordAccessPolicy {
    fn view_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool;
    fn edit_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool;

    /// When true, same-organization members may edit non-reference records they do not own.
    fn organization_member_edit_allowed() -> bool {
        true
    }
}

/// Ruby: `Domain::Shared::ReferenceRecordAccessFilter`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReferenceRecordAccessFilter<P> {
    user: User,
    member_organization_ids: Vec<i64>,
    _policy: PhantomData<P>,
}

impl<P: RecordAccessPolicy> ReferenceRecordAccessFilter<P> {
    pub fn new(user: User, member_organization_ids: Vec<i64>) -> Self {
        Self {
            user,
            member_organization_ids,
            _policy: PhantomData,
        }
    }

    pub fn user(&self) -> &User {
        &self.user
    }

    pub fn member_organization_ids(&self) -> &[i64] {
        &self.member_organization_ids
    }

    pub fn view_allows(
        &self,
        is_reference: bool,
        record_user_id: Option<i64>,
        record_organization_id: Option<i64>,
    ) -> bool {
        if P::view_allowed(&self.user, is_reference, record_user_id) {
            return true;
        }
        organization_member_access(
            &self.member_organization_ids,
            is_reference,
            record_organization_id,
        )
    }

    pub fn edit_allows(
        &self,
        is_reference: bool,
        record_user_id: Option<i64>,
        record_organization_id: Option<i64>,
    ) -> bool {
        if P::edit_allowed(&self.user, is_reference, record_user_id) {
            return true;
        }
        if !P::organization_member_edit_allowed() {
            return false;
        }
        organization_member_access(
            &self.member_organization_ids,
            is_reference,
            record_organization_id,
        )
    }
}

#[cfg(test)]
mod reference_record_access_filter_test_inline {
    use super::*;
    use crate::shared::user::User;

    #[derive(Debug, Clone, Copy, PartialEq, Eq)]
    struct OwnerOnlyPolicy;

    impl RecordAccessPolicy for OwnerOnlyPolicy {
        fn view_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
            user.admin || is_reference || record_user_id == Some(user.id)
        }

        fn edit_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
            user.admin || (!is_reference && record_user_id == Some(user.id))
        }

        fn organization_member_edit_allowed() -> bool {
            false
        }
    }

    #[derive(Debug, Clone, Copy, PartialEq, Eq)]
    struct OrgMemberEditPolicy;

    impl RecordAccessPolicy for OrgMemberEditPolicy {
        fn view_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
            OwnerOnlyPolicy::view_allowed(user, is_reference, record_user_id)
        }

        fn edit_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool {
            OwnerOnlyPolicy::edit_allowed(user, is_reference, record_user_id)
        }
    }

    #[test]
    fn org_member_can_view_team_record_but_not_edit_when_org_edit_disabled() {
        let filter = ReferenceRecordAccessFilter::<OwnerOnlyPolicy>::new(User::new(2, false), vec![10]);
        assert!(filter.view_allows(false, Some(1), Some(10)));
        assert!(!filter.edit_allows(false, Some(1), Some(10)));
    }

    #[test]
    fn org_member_can_edit_team_record_when_org_edit_enabled() {
        let filter =
            ReferenceRecordAccessFilter::<OrgMemberEditPolicy>::new(User::new(2, false), vec![10]);
        assert!(filter.view_allows(false, Some(1), Some(10)));
        assert!(filter.edit_allows(false, Some(1), Some(10)));
    }

    #[test]
    fn reference_records_never_gain_access_via_organization_membership() {
        let filter =
            ReferenceRecordAccessFilter::<OrgMemberEditPolicy>::new(User::new(2, false), vec![10]);
        assert!(filter.view_allows(true, Some(1), Some(10)));
        assert!(!filter.edit_allows(true, Some(1), Some(10)));
    }

    #[test]
    fn admin_bypasses_owner_and_org_checks() {
        let filter = ReferenceRecordAccessFilter::<OwnerOnlyPolicy>::new(User::new(99, true), vec![]);
        assert!(filter.view_allows(false, Some(1), Some(10)));
        assert!(filter.edit_allows(false, Some(1), Some(10)));
    }
}
