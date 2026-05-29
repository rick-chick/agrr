//! Ruby: `Domain::CultivationPlan::Calculators::AmountUnitConversionCalculator`

use rust_decimal::Decimal;
use std::collections::BTreeMap;
use std::str::FromStr;

use thiserror::Error;

const CONVERSION_TOLERANCE: Decimal = Decimal::from_parts(1, 0, 0, false, 4);

#[derive(Debug, Error, PartialEq, Eq)]
#[error("unit conversion error")]
pub struct UnitConversionError;

#[derive(Debug, Clone)]
pub struct AmountUnitConversionCalculator;

impl AmountUnitConversionCalculator {
    pub fn apply_to_update_attributes(
        &self,
        attributes: &BTreeMap<String, String>,
        current_amount: Option<Decimal>,
        current_unit: Option<&str>,
        new_unit: Option<&str>,
        amount_param: Option<&str>,
    ) -> Option<BTreeMap<String, String>> {
        if !attributes.contains_key("amount_unit") {
            return None;
        }
        let new_unit = new_unit.filter(|s| !s.trim().is_empty())?;
        let current_unit = current_unit.filter(|s| !s.trim().is_empty())?;
        if new_unit == current_unit {
            return None;
        }
        let current_amount = current_amount?;
        if let Some(param) = amount_param.filter(|s| !s.trim().is_empty()) {
            let param_amount = decimal_from(param)?;
            let current = decimal_from_decimal(current_amount)?;
            if !approx_equal(param_amount, current) {
                return None;
            }
        }
        let converted = self.convert_per_area_amount(current_amount, current_unit, new_unit).ok()?;
        let mut out = attributes.clone();
        out.insert("amount".into(), converted.to_string());
        Some(out)
    }

    pub fn convert_per_area_amount(
        &self,
        amount: Decimal,
        from: &str,
        to: &str,
    ) -> Result<Decimal, UnitConversionError> {
        let (from_numerator, from_area) = parse_per_area_unit(from)?;
        let (to_numerator, to_area) = parse_per_area_unit(to)?;

        let from_meta = amount_numerator_meta(&from_numerator)?;
        let to_meta = amount_numerator_meta(&to_numerator)?;
        if from_meta.0 != to_meta.0 {
            return Err(UnitConversionError);
        }

        let from_area_factor = area_unit_factor(&from_area)?;
        let to_area_factor = area_unit_factor(&to_area)?;

        let amount_in_base = amount * from_meta.1;
        let amount_per_m2 = amount_in_base / from_area_factor;
        let target_in_base = amount_per_m2 * to_area_factor;
        Ok(target_in_base / to_meta.1)
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum AmountBase {
    Liter,
    Gram,
}

fn amount_numerator_meta(unit: &str) -> Result<(AmountBase, Decimal), UnitConversionError> {
    // unit is already normalized (lowercase)
    match unit {
        "ml" => Ok((AmountBase::Liter, Decimal::new(1, 3))),
        "l" => Ok((AmountBase::Liter, Decimal::ONE)),
        "g" => Ok((AmountBase::Gram, Decimal::ONE)),
        "kg" => Ok((AmountBase::Gram, Decimal::new(1000, 0))),
        _ => Err(UnitConversionError),
    }
}

fn area_unit_factor(unit: &str) -> Result<Decimal, UnitConversionError> {
    match unit {
        "m2" => Ok(Decimal::ONE),
        "a" => Ok(Decimal::new(100, 0)),
        "10a" => Ok(Decimal::new(1000, 0)),
        "ha" => Ok(Decimal::new(10000, 0)),
        _ => Err(UnitConversionError),
    }
}

fn parse_per_area_unit(unit: &str) -> Result<(String, String), UnitConversionError> {
    let parts: Vec<&str> = unit.split('/').collect();
    if parts.len() != 2 {
        return Err(UnitConversionError);
    }
    Ok((
        normalize_amount_unit(parts[0]),
        normalize_area_unit(parts[1]),
    ))
}

fn normalize_amount_unit(unit: &str) -> String {
    unit.trim().to_lowercase()
}

fn normalize_area_unit(unit: &str) -> String {
    let value = unit.trim().to_lowercase();
    if value == "㎡" {
        "m2".into()
    } else {
        value
    }
}

fn decimal_from(value: &str) -> Option<Decimal> {
    Decimal::from_str(value).ok()
}

fn decimal_from_decimal(value: Decimal) -> Option<Decimal> {
    Some(value)
}

fn approx_equal(left: Decimal, right: Decimal) -> bool {
    (left - right).abs() <= CONVERSION_TOLERANCE
}

impl Default for AmountUnitConversionCalculator {
    fn default() -> Self {
        Self
    }
}

#[cfg(test)]
mod calculators_amount_unit_conversion_calculator_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/calculators_amount_unit_conversion_calculator_test.rs"));
}
