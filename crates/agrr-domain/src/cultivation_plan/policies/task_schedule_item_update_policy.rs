//! Ruby: `Domain::CultivationPlan::Policies::TaskScheduleItemUpdatePolicy`

use std::collections::BTreeMap;

use rust_decimal::Decimal;
use time::{Date, OffsetDateTime};

use crate::agricultural_task::constants::task_schedule_item_statuses::RESCHEDULED;
use crate::cultivation_plan::calculators::amount_unit_conversion_calculator::AmountUnitConversionCalculator;
use crate::cultivation_plan::dtos::TaskScheduleItemAmountSnapshot;
use crate::cultivation_plan::policies::task_schedule_item_create_policy::parse_scheduled_date;

fn format_date(date: Date) -> String {
    format!(
        "{:04}-{:02}-{:02}",
        date.year(),
        u8::from(date.month()),
        date.day()
    )
}

fn format_datetime(dt: OffsetDateTime) -> String {
    dt.unix_timestamp().to_string()
}

/// Ruby: `TaskScheduleItemUpdatePolicy.build_update_attributes`
pub fn build_update_attributes(
    attributes_seed: &BTreeMap<String, String>,
    amount_snapshot: &TaskScheduleItemAmountSnapshot,
    calculator: &AmountUnitConversionCalculator,
    rescheduled_at: OffsetDateTime,
) -> BTreeMap<String, String> {
    let mut attributes = attributes_seed.clone();

    if let Some(raw) = attributes.get("scheduled_date").filter(|s| !s.trim().is_empty()) {
        if let Ok(new_date) = parse_scheduled_date(raw) {
            attributes.insert("scheduled_date".into(), format_date(new_date));
            if amount_snapshot.scheduled_date != new_date {
                attributes.insert("rescheduled_at".into(), format_datetime(rescheduled_at));
                attributes.insert("status".into(), RESCHEDULED.to_string());
            }
        }
    }

    let converted = calculator.apply_to_update_attributes(
        &attributes,
        amount_snapshot.amount,
        amount_snapshot.amount_unit.as_deref(),
        attributes.get("amount_unit").map(String::as_str),
        attributes.get("amount").map(String::as_str),
    );
    converted.unwrap_or(attributes)
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal::Decimal;
    use time::macros::{date, datetime};

    fn amount_snapshot(scheduled_date: Date) -> TaskScheduleItemAmountSnapshot {
        TaskScheduleItemAmountSnapshot {
            amount: Some(Decimal::ONE),
            amount_unit: Some("kg/ha".into()),
            scheduled_date,
        }
    }

    // Ruby: test "build_update_attributes sets rescheduled when scheduled_date changes"
    #[test]
    fn build_update_attributes_sets_rescheduled_when_scheduled_date_changes() {
        let rescheduled_at = datetime!(2026-06-01 12:00:00 UTC);
        let mut seed = BTreeMap::new();
        seed.insert("scheduled_date".into(), "2026-06-15".into());
        seed.insert("name".into(), "作業".into());

        let result = build_update_attributes(
            &seed,
            &amount_snapshot(date!(2026-05-01)),
            &AmountUnitConversionCalculator,
            rescheduled_at,
        );

        assert_eq!(result.get("scheduled_date").map(String::as_str), Some("2026-06-15"));
        assert_eq!(result.get("name").map(String::as_str), Some("作業"));
        assert!(result.contains_key("rescheduled_at"));
        assert_eq!(result.get("status").map(String::as_str), Some(RESCHEDULED));
    }

    // Ruby: test "build_update_attributes does not reschedule when scheduled_date unchanged"
    #[test]
    fn build_update_attributes_does_not_reschedule_when_scheduled_date_unchanged() {
        let rescheduled_at = datetime!(2026-06-01 12:00:00 UTC);
        let mut seed = BTreeMap::new();
        seed.insert("scheduled_date".into(), "2026-05-01".into());

        let result = build_update_attributes(
            &seed,
            &amount_snapshot(date!(2026-05-01)),
            &AmountUnitConversionCalculator,
            rescheduled_at,
        );

        assert_eq!(result.get("scheduled_date").map(String::as_str), Some("2026-05-01"));
        assert!(!result.contains_key("rescheduled_at"));
        assert!(!result.contains_key("status"));
    }

    // Ruby: test "build_update_attributes applies calculator unit conversion"
    #[test]
    fn build_update_attributes_applies_calculator_unit_conversion() {
        let rescheduled_at = datetime!(2026-06-01 12:00:00 UTC);
        let mut seed = BTreeMap::new();
        seed.insert("amount_unit".into(), "g/m2".into());
        seed.insert("amount".into(), "1.0".into());

        let result = build_update_attributes(
            &seed,
            &amount_snapshot(date!(2026-05-01)),
            &AmountUnitConversionCalculator,
            rescheduled_at,
        );

        let amount: f64 = result["amount"].parse().unwrap();
        assert!((amount - 0.1).abs() < 0.0001);
        assert_eq!(result.get("amount_unit").map(String::as_str), Some("g/m2"));
    }

    // Ruby: test "build_update_attributes omits reschedule when scheduled_date blank"
    #[test]
    fn build_update_attributes_omits_reschedule_when_scheduled_date_blank() {
        let rescheduled_at = datetime!(2026-06-01 12:00:00 UTC);
        let mut seed = BTreeMap::new();
        seed.insert("name".into(), "作業のみ".into());

        let result = build_update_attributes(
            &seed,
            &amount_snapshot(date!(2026-05-01)),
            &AmountUnitConversionCalculator,
            rescheduled_at,
        );

        assert_eq!(result.get("name").map(String::as_str), Some("作業のみ"));
        assert!(!result.contains_key("rescheduled_at"));
        assert!(!result.contains_key("status"));
    }
}
