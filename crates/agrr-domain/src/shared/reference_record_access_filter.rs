use std::marker::PhantomData;

use crate::shared::user::User;

/// Policy module bound to [`ReferenceRecordAccessFilter`] (Ruby: `policy_module` class).
pub trait RecordAccessPolicy {
    fn view_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool;
    fn edit_allowed(user: &User, is_reference: bool, record_user_id: Option<i64>) -> bool;
}

/// Ruby: `Domain::Shared::ReferenceRecordAccessFilter`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ReferenceRecordAccessFilter<P> {
    user: User,
    _policy: PhantomData<P>,
}

impl<P: RecordAccessPolicy> ReferenceRecordAccessFilter<P> {
    pub fn new(user: User) -> Self {
        Self {
            user,
            _policy: PhantomData,
        }
    }

    pub fn user(&self) -> &User {
        &self.user
    }

    pub fn view_allows(&self, is_reference: bool, record_user_id: Option<i64>) -> bool {
        P::view_allowed(&self.user, is_reference, record_user_id)
    }

    pub fn edit_allows(&self, is_reference: bool, record_user_id: Option<i64>) -> bool {
        P::edit_allowed(&self.user, is_reference, record_user_id)
    }
}
