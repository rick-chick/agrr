use std::marker::PhantomData;

use crate::shared::org_scope::organization_member_access;
use crate::shared::user::User;

/// Policy module bound to [`ReferenceRecordAccessFilter`] (Ruby: `policy_module` class).
pub trait RecordAccessPolicy {
    fn view_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool;
    fn edit_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool;
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
        organization_member_access(
            &self.member_organization_ids,
            is_reference,
            record_organization_id,
        )
    }
}
