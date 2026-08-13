//! Validates proposal application progress status values.

use std::collections::BTreeMap;

use crate::shared::exceptions::RecordInvalidError;

const VALID_STATUSES: &[&str] = &[
    "not_started",
    "applied_pending_confirmation",
    "confirmed",
    "done",
    "dismissed",
];

pub fn validate_proposal_application_progress_updates(
    updates: &BTreeMap<String, String>,
) -> Result<(), RecordInvalidError> {
    for (proposal_key, status) in updates {
        if proposal_key.trim().is_empty() {
            return Err(RecordInvalidError::new(
                Some("proposal_key is required".into()),
                None,
            ));
        }
        if !VALID_STATUSES.contains(&status.as_str()) {
            return Err(RecordInvalidError::new(
                Some("invalid proposal status".into()),
                None,
            ));
        }
    }
    Ok(())
}
