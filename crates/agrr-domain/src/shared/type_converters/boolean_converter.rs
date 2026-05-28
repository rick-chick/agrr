/// Ruby: `Domain::Shared::TypeConverters::BooleanConverter.cast`
pub fn cast_boolean(value: &serde_json::Value) -> bool {
    match value {
        serde_json::Value::Bool(b) => *b,
        serde_json::Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                matches!(i, 1)
            } else {
                false
            }
        }
        serde_json::Value::String(s) => cast_boolean_str(s),
        serde_json::Value::Null => false,
        _ => false,
    }
}

pub fn cast_boolean_attr(value: &crate::shared::attr::AttrValue) -> bool {
    match value {
        crate::shared::attr::AttrValue::Bool(b) => *b,
        crate::shared::attr::AttrValue::Int(i) => *i == 1,
        crate::shared::attr::AttrValue::Str(s) => cast_boolean_str(s),
        crate::shared::attr::AttrValue::Null => false,
    }
}

fn cast_boolean_str(s: &str) -> bool {
    let normalized = s.trim().to_ascii_lowercase();
    matches!(
        normalized.as_str(),
        "true" | "1" | "yes" | "on" | "t" | "y"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cast_truthy_strings() {
        assert!(cast_boolean_str("true"));
        assert!(cast_boolean_str("1"));
    }

    #[test]
    fn cast_falsy_nil_and_empty() {
        assert!(!cast_boolean(&serde_json::Value::Null));
        assert!(!cast_boolean_str(""));
    }
}
