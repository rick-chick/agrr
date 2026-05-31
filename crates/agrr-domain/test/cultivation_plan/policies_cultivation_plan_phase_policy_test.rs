// Tests for `policies/cultivation_plan_phase_policy.rs` (Ruby parity under test/domain/cultivation_plan/policies/).

use crate::cultivation_plan::dtos::CultivationPlanPhaseName;
use crate::cultivation_plan::policies::cultivation_plan_phase_policy::build;

// Ruby: test "build start_optimizing sets initializing phase with broadcast"
#[test]
fn build_start_optimizing_sets_initializing_phase_with_broadcast() {
    let built = build(CultivationPlanPhaseName::StartOptimizing, None);

    assert_eq!(built.attrs.get("status").map(String::as_str), Some("optimizing"));
    assert_eq!(
        built.attrs.get("optimization_phase").map(String::as_str),
        Some("initializing")
    );
    assert_eq!(
        built.message_key.as_deref(),
        Some("models.cultivation_plan.phases.initializing")
    );
    assert!(built.broadcast);
}

// Ruby: test "build phase phase_attrs with message key and broadcast"
#[test]
fn build_phase_fetching_weather_with_message_key_and_broadcast() {
    let built = build(CultivationPlanPhaseName::PhaseFetchingWeather, None);

    assert_eq!(
        built.attrs.get("optimization_phase").map(String::as_str),
        Some("fetching_weather")
    );
    assert_eq!(
        built.message_key.as_deref(),
        Some("models.cultivation_plan.phases.fetching_weather")
    );
    assert!(built.broadcast);
}

// Ruby: test "build phase_failed uses failure subphase message key"
#[test]
fn build_phase_failed_uses_failure_subphase_message_key() {
    let built = build(
        CultivationPlanPhaseName::PhaseFailed,
        Some("task_schedule_generation"),
    );

    assert_eq!(built.attrs.get("optimization_phase").map(String::as_str), Some("failed"));
    assert_eq!(built.attrs.get("status").map(String::as_str), Some("failed"));
    assert_eq!(
        built.message_key.as_deref(),
        Some("models.cultivation_plan.phase_failed.task_schedule_generation")
    );
    assert!(built.broadcast);
}

// Ruby: test "build phase_failed defaults message key when subphase unknown"
#[test]
fn build_phase_failed_defaults_message_key_when_subphase_unknown() {
    let built = build(CultivationPlanPhaseName::PhaseFailed, None);

    assert_eq!(
        built.message_key.as_deref(),
        Some("models.cultivation_plan.phase_failed.default")
    );
}

// Ruby: test "build accepts string phase name" — completed variant on enum
#[test]
fn build_phase_completed_with_message_key_and_broadcast() {
    let built = build(CultivationPlanPhaseName::PhaseCompleted, None);

    assert_eq!(
        built.attrs.get("optimization_phase").map(String::as_str),
        Some("completed")
    );
    assert_eq!(
        built.message_key.as_deref(),
        Some("models.cultivation_plan.phases.completed")
    );
    assert!(built.broadcast);
}
