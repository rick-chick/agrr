// Tests for `policies/plan_variance_threshold_policy.rs`.

use super::*;

fn sample_item(delta_days: Option<i64>, gdd_delta: Option<f64>) -> PlanVsActualItemRead {
    PlanVsActualItemRead {
        item_id: 1,
        field_cultivation_id: 100,
        category: "general".into(),
        name: "Task".into(),
        scheduled_date: Some("2026-06-01".into()),
        actual_date: Some("2026-06-08".into()),
        delta_days,
        gdd_trigger: Some(100.0),
        gdd_at_actual: Some(110.0),
        gdd_delta,
        amount_planned: None,
        amount_actual: None,
        amount_delta: None,
        amount_unit: None,
    }
}

#[test]
fn exceedance_kind_none_when_within_thresholds() {
    assert_eq!(None, exceedance_kind(&sample_item(Some(3), Some(10.0))));
    assert_eq!(None, exceedance_kind(&sample_item(Some(-2), Some(5.0))));
}

#[test]
fn exceedance_kind_days_when_delta_exceeds_threshold() {
    assert_eq!(
        Some(VarianceExceedanceKind::Days),
        exceedance_kind(&sample_item(Some(4), Some(5.0)))
    );
    assert_eq!(
        Some(VarianceExceedanceKind::Days),
        exceedance_kind(&sample_item(Some(-4), None))
    );
}

#[test]
fn exceedance_kind_gdd_when_gdd_delta_exceeds_threshold() {
    assert_eq!(
        Some(VarianceExceedanceKind::Gdd),
        exceedance_kind(&sample_item(Some(1), Some(10.5)))
    );
    assert_eq!(
        Some(VarianceExceedanceKind::Gdd),
        exceedance_kind(&sample_item(None, Some(-11.0)))
    );
}

#[test]
fn exceedance_kind_both_when_days_and_gdd_exceed() {
    assert_eq!(
        Some(VarianceExceedanceKind::Both),
        exceedance_kind(&sample_item(Some(5), Some(12.0)))
    );
}

#[test]
fn amount_delta_threshold_differs_by_fertilizer_and_pest_control() {
    assert_eq!(
        FERTILIZER_AMOUNT_DELTA_THRESHOLD,
        amount_delta_threshold_for_category("fertilizer")
    );
    assert_eq!(
        PEST_CONTROL_AMOUNT_DELTA_THRESHOLD,
        amount_delta_threshold_for_category("pest_control")
    );
    assert_ne!(
        amount_delta_threshold_for_category("fertilizer"),
        amount_delta_threshold_for_category("pest_control")
    );
}

#[test]
fn amount_delta_threshold_falls_back_to_default_for_other_categories() {
    assert_eq!(
        DEFAULT_AMOUNT_DELTA_THRESHOLD,
        amount_delta_threshold_for_category("general")
    );
}

#[test]
fn amount_delta_exceeds_threshold_uses_category_specific_values() {
    assert!(amount_delta_exceeds_threshold(0.3, "pest_control"));
    assert!(!amount_delta_exceeds_threshold(0.3, "fertilizer"));
}
