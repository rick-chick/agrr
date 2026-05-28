use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::record_ref::RecordRef;
use crate::shared::reference_record_access_filter::{RecordAccessPolicy, ReferenceRecordAccessFilter};

/// Ruby: `Domain::Shared::ReferenceRecordAuthorization`
pub fn referencable_is_reference<R: RecordRef>(record: &R) -> bool {
    record.is_reference()
}

pub fn referencable_user_id<R: RecordRef>(record: &R) -> Option<i64> {
    record.user_id()
}

pub fn assert_view_allowed<P: RecordAccessPolicy, R: RecordRef>(
    access_filter: &ReferenceRecordAccessFilter<P>,
    record: &R,
) -> Result<(), PolicyPermissionDenied> {
    if access_filter.view_allows(record.is_reference(), record.user_id()) {
        Ok(())
    } else {
        Err(PolicyPermissionDenied)
    }
}

pub fn assert_edit_allowed<P: RecordAccessPolicy, R: RecordRef>(
    access_filter: &ReferenceRecordAccessFilter<P>,
    record: &R,
) -> Result<(), PolicyPermissionDenied> {
    if access_filter.edit_allows(record.is_reference(), record.user_id()) {
        Ok(())
    } else {
        Err(PolicyPermissionDenied)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::shared::policies::crop_policy::record_access_filter;
    use crate::shared::record_ref::RecordStub;
    use crate::shared::user::User;

    #[test]
    fn assert_view_allowed_passes_when_policy_allows() {
        let user = User::new(1, false);
        let filter = record_access_filter(user);
        let record = RecordStub {
            is_reference: true,
            user_id: Some(99),
        };
        assert!(assert_view_allowed(&filter, &record).is_ok());
    }

    #[test]
    fn assert_view_allowed_denies_other_users_non_reference() {
        let user = User::new(1, false);
        let filter = record_access_filter(user);
        let record = RecordStub {
            is_reference: false,
            user_id: Some(99),
        };
        assert_eq!(
            assert_view_allowed(&filter, &record),
            Err(PolicyPermissionDenied)
        );
    }

    #[test]
    fn assert_edit_allowed_denies_non_owner_private_record() {
        let user = User::new(1, false);
        let filter = record_access_filter(user);
        let record = RecordStub {
            is_reference: false,
            user_id: Some(99),
        };
        assert_eq!(
            assert_edit_allowed(&filter, &record),
            Err(PolicyPermissionDenied)
        );
    }
}
