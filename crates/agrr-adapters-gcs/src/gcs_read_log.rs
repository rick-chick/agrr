//! Per-read `gcs_read` lines for Cloud Logging (`textPayload` grep).
//!
//! Callers may attach an opaque suffix (e.g. optimization-chain `plan_id` / `step`) via
//! [`set_gcs_read_log_suffix`] without this module interpreting it.

use std::cell::RefCell;

thread_local! {
    static LOG_SUFFIX: RefCell<Option<String>> = const { RefCell::new(None) };
}

/// Replaces the suffix appended to each [`log_read`] line until cleared with `None`.
pub fn set_gcs_read_log_suffix(suffix: Option<String>) {
    LOG_SUFFIX.with(|slot| {
        *slot.borrow_mut() = suffix;
    });
}

/// Test-only observation of the active suffix (`#[doc(hidden)]`).
#[doc(hidden)]
pub fn gcs_read_log_suffix_snapshot() -> Option<String> {
    LOG_SUFFIX.with(|slot| slot.borrow().clone())
}

pub(crate) fn log_read(bucket: &str, key: &str) {
    let suffix = LOG_SUFFIX.with(|slot| slot.borrow().clone());
    let line = match suffix {
        Some(extra) => format!("gcs_read bucket={bucket} key={key}{extra}"),
        None => format!("gcs_read bucket={bucket} key={key}"),
    };
    eprintln!("{line}");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn set_gcs_read_log_suffix_roundtrip_and_clear() {
        set_gcs_read_log_suffix(Some(" plan_id=9 step=bootstrap".into()));
        assert_eq!(
            gcs_read_log_suffix_snapshot().as_deref(),
            Some(" plan_id=9 step=bootstrap")
        );

        set_gcs_read_log_suffix(None);
        assert_eq!(gcs_read_log_suffix_snapshot(), None);
    }
}
