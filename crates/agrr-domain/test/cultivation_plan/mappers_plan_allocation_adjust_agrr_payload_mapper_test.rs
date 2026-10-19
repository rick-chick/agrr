// Tests for `mappers/plan_allocation_adjust_agrr_payload_mapper.rs`.

use crate::cultivation_plan::dtos::PlanAllocationAdjustReadSnapshot;
use crate::cultivation_plan::mappers::PlanAllocationAdjustAgrrPayloadMapper;

// Locks docs/spec-defects/06 H1: adjust agrr payload keeps crops that have stages but no requirement JSON.
#[test]
fn to_crops_config_includes_crop_id_only_when_requirement_missing_but_growth_stages_exist() {
    let snapshot = PlanAllocationAdjustReadSnapshot::minimal_for_tests(2, "Pepper", true);
    assert!(
        snapshot.plan_crop_snapshots[0].agrr_requirement.is_none(),
        "fixture must model gateway gap: has_growth_stages without agrr_requirement"
    );

    let crops = PlanAllocationAdjustAgrrPayloadMapper::to_crops_config(&snapshot, None);

    assert_eq!(crops.len(), 1);
    assert_eq!(crops[0]["crop"]["crop_id"], "1");
    assert!(crops[0].get("stages").is_none());
}
