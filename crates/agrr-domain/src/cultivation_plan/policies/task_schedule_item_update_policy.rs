//! Ruby: `Domain::CultivationPlan::Policies::TaskScheduleItemUpdatePolicy`

use std::collections::BTreeMap;

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
mod policies_task_schedule_item_update_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/policies_task_schedule_item_update_policy_test.rs"));
}
