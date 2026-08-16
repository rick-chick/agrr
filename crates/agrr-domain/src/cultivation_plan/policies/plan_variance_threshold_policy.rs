//! Threshold policy for plan-vs-actual variance that requires user action.

use crate::cultivation_plan::dtos::plan_vs_actual::PlanVsActualItemRead;

/// Default day variance threshold (absolute delta days).
pub const DEFAULT_DAYS_THRESHOLD: i64 = 3;

/// Default GDD variance threshold (absolute delta).
pub const DEFAULT_GDD_THRESHOLD: f64 = 10.0;

/// Default amount variance threshold (absolute average delta).
pub const DEFAULT_AMOUNT_DELTA_THRESHOLD: f64 = 0.5;

/// Fertilizer amount variance threshold (kg-scale bulk application).
pub const FERTILIZER_AMOUNT_DELTA_THRESHOLD: f64 = 0.5;

/// Pest-control amount variance threshold (L-scale spray precision).
pub const PEST_CONTROL_AMOUNT_DELTA_THRESHOLD: f64 = 0.25;

/// Returns the amount delta threshold for structured-input categories.
pub fn amount_delta_threshold_for_category(category: &str) -> f64 {
    match category {
        "fertilizer" => FERTILIZER_AMOUNT_DELTA_THRESHOLD,
        "pest_control" => PEST_CONTROL_AMOUNT_DELTA_THRESHOLD,
        _ => DEFAULT_AMOUNT_DELTA_THRESHOLD,
    }
}

/// Returns true when an item's amount delta exceeds the category threshold.
pub fn amount_delta_exceeds_threshold(delta: f64, category: &str) -> bool {
    delta.abs() >= amount_delta_threshold_for_category(category)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VarianceExceedanceKind {
    Days,
    Gdd,
    Both,
}

impl VarianceExceedanceKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Days => "days",
            Self::Gdd => "gdd",
            Self::Both => "both",
        }
    }
}

/// Returns the exceedance kind when the item exceeds day and/or GDD thresholds.
pub fn exceedance_kind(item: &PlanVsActualItemRead) -> Option<VarianceExceedanceKind> {
    let days_exceeded = item
        .delta_days
        .map(|days| days.unsigned_abs() > DEFAULT_DAYS_THRESHOLD as u64)
        .unwrap_or(false);
    let gdd_exceeded = item
        .gdd_delta
        .map(|delta| delta.abs() > DEFAULT_GDD_THRESHOLD)
        .unwrap_or(false);

    match (days_exceeded, gdd_exceeded) {
        (true, true) => Some(VarianceExceedanceKind::Both),
        (true, false) => Some(VarianceExceedanceKind::Days),
        (false, true) => Some(VarianceExceedanceKind::Gdd),
        (false, false) => None,
    }
}

#[cfg(test)]
mod policies_plan_variance_threshold_policy_test_inline {
    use super::*;
    use crate::cultivation_plan::dtos::plan_vs_actual::PlanVsActualItemRead;

    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/policies_plan_variance_threshold_policy_test.rs"
    ));
}
