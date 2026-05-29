//! Ruby: `Domain::Shared::ValidationHelpers`

use serde_json::Value;

use crate::shared::hash::to_array;

/// Ruby: `ValidationHelpers.blank?`
pub fn blank(value: &Value) -> bool {
    crate::shared::hash::blank(value)
}

/// Ruby: `ValidationHelpers.present?`
pub fn present(value: &Value) -> bool {
    crate::shared::hash::present(value)
}

/// Ruby: `ValidationHelpers.to_array`
pub fn to_array_value(value: Option<&Value>) -> Vec<Value> {
    to_array(value)
}

#[cfg(test)]
mod validation_validation_helpers_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/validation_validation_helpers_test.rs"));
}
