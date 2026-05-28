//! Ruby: `Domain::Shared::TypeConverters::BigDecimalConverter`

use rust_decimal::Decimal;

/// Cast external numeric values to [`Decimal`]; empty string → `None`.
pub fn cast_big_decimal(value: Option<&str>) -> Option<Decimal> {
    match value {
        None => None,
        Some(s) if s.is_empty() => None,
        Some(s) => s.parse().ok(),
    }
}

pub fn cast_big_decimal_decimal(value: Option<Decimal>) -> Option<Decimal> {
    value
}

pub fn cast_big_decimal_json(value: Option<&serde_json::Value>) -> Option<Decimal> {
    match value {
        None | Some(serde_json::Value::Null) => None,
        Some(serde_json::Value::String(s)) => cast_big_decimal(Some(s.as_str())),
        Some(serde_json::Value::Number(n)) => {
            if let Some(i) = n.as_i64() {
                Some(Decimal::from(i))
            } else if let Some(f) = n.as_f64() {
                Decimal::try_from(f).ok()
            } else {
                None
            }
        }
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal::Decimal;
    use std::str::FromStr;

    #[test]
    fn preserves_decimal_and_handles_empty() {
        let bd = Decimal::from_str("1.25").unwrap();
        assert_eq!(cast_big_decimal_decimal(Some(bd)), Some(bd));
        assert_eq!(
            cast_big_decimal(Some("3")),
            Some(Decimal::from_str("3").unwrap())
        );
        assert_eq!(cast_big_decimal(None), None);
        assert_eq!(cast_big_decimal(Some("")), None);
    }
}
