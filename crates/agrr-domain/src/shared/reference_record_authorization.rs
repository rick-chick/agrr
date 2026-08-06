use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::record_ref::RecordRef;
use crate::shared::reference_record_access_filter::{RecordAccessPolicy, ReferenceRecordAccessFilter};

/// Ruby: `Domain::Shared::ReferenceRecordAuthorization`
pub fn assert_view_allowed<P: RecordAccessPolicy, R: RecordRef>(
    access_filter: &ReferenceRecordAccessFilter<P>,
    record: &R,
) -> Result<(), PolicyPermissionDenied> {
    if access_filter.view_allows(
        record.is_reference(),
        record.user_id(),
        record.organization_id(),
    ) {
        Ok(())
    } else {
        Err(PolicyPermissionDenied)
    }
}

pub fn assert_edit_allowed<P: RecordAccessPolicy, R: RecordRef>(
    access_filter: &ReferenceRecordAccessFilter<P>,
    record: &R,
) -> Result<(), PolicyPermissionDenied> {
    if access_filter.edit_allows(
        record.is_reference(),
        record.user_id(),
        record.organization_id(),
    ) {
        Ok(())
    } else {
        Err(PolicyPermissionDenied)
    }
}

#[cfg(test)]
mod reference_record_authorization_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/reference_record_authorization_test.rs"));
}
