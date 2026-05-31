// Tests for `mappers/cultivation_plan_phase_broadcast_payload_mapper.rs`

use crate::cultivation_plan::entities::CultivationPlanEntity;
use crate::cultivation_plan::mappers::to_port_payload;

fn plan_with_phase(phase: &str, message: &str) -> CultivationPlanEntity {
    CultivationPlanEntity {
        id: 1,
        farm_id: 1,
        user_id: 1,
        total_area: 0.0,
        plan_type: "public".into(),
        plan_year: None,
        plan_name: None,
        planning_start_date: None,
        planning_end_date: None,
        status: Some("optimizing".into()),
        session_id: None,
        display_name: None,
        optimization_phase: Some(phase.into()),
        optimization_phase_message: Some(message.into()),
        cultivation_plan_crops_count: 0,
        cultivation_plan_fields_count: 0,
        created_at: None,
        updated_at: None,
    }
}

#[test]
fn failed_phase_uses_phase_failed_message_key_not_phases_failed() {
    let plan = plan_with_phase(
        "failed",
        "models.cultivation_plan.phase_failed.predicting_weather",
    );
    let payload = to_port_payload(&plan, 0, plan.optimization_phase_message.as_deref());

    assert_eq!(
        payload["message_key"],
        "models.cultivation_plan.phase_failed.predicting_weather"
    );
}

#[test]
fn legacy_rails_only_phase_maps_to_optimizing_message_key() {
    let plan = plan_with_phase(
        "optimization_completed",
        "最適化が完了しました。作業予定を生成しています...",
    );
    let payload = to_port_payload(&plan, 50, plan.optimization_phase_message.as_deref());

    assert_eq!(payload["phase"], "optimizing");
    assert_eq!(
        payload["message_key"],
        "models.cultivation_plan.phases.optimizing"
    );
    assert!(payload["phase_message"].is_null());
}
