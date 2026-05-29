//! Ruby: `Domain::Shared::ValidationErrorHash`

use std::collections::BTreeMap;

use crate::shared::validation::validation_errors::ValidationErrors;

/// Presenter-oriented string-keyed error hash (Ruby: `Domain::Shared::ValidationErrorHash`).
pub type ValidationErrorHash = BTreeMap<String, Vec<String>>;

pub fn from_message(message: impl Into<String>) -> ValidationErrorHash {
    let mut map = BTreeMap::new();
    map.insert("base".into(), vec![message.into()]);
    map
}

/// Presenter-oriented string-keyed error hash.
pub fn from_errors(errors: ErrorsInput<'_>) -> ValidationErrorHash {
    match errors {
        ErrorsInput::Hash(h) => h,
        ErrorsInput::None => BTreeMap::new(),
        ErrorsInput::ValidationErrors(ve) => ve
            .messages()
            .into_iter()
            .map(|(k, msgs)| {
                (
                    k,
                    msgs.into_iter().filter(|m| !m.is_empty()).collect(),
                )
            })
            .collect(),
    }
}

pub enum ErrorsInput<'a> {
    None,
    Hash(BTreeMap<String, Vec<String>>),
    ValidationErrors(&'a ValidationErrors),
}

#[cfg(test)]
mod validation_validation_error_hash_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/validation_validation_error_hash_test.rs"));
}
