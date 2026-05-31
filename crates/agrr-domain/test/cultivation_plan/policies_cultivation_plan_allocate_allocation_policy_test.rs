use super::{
    allocation_result_persistable, allocation_row_persistable,
};
use serde_json::json;

#[test]
fn allocation_row_persistable_accepts_agrr_allocate_row() {
    let row = json!({
        "allocation_id": "64ed98ca-9813-47cd-a668-277f210de93d",
        "crop_id": "7",
        "crop_name": "キャベツ",
        "variety": "春キャベツ",
        "area_used": 300.0,
        "start_date": "2027-04-21T00:00:00",
        "completion_date": "2027-08-29T00:00:00",
        "growth_days": 131,
        "accumulated_gdd": 2200.15,
        "total_cost": 1310.0,
        "expected_revenue": 264000.0,
        "profit": 262690.0
    });
    assert!(allocation_row_persistable(&row));
}

#[test]
fn allocation_row_persistable_rejects_planning_period_placeholder() {
    let row = json!({
        "crop_id": "7",
        "area_used": 1.0,
        "start_date": "2026-05-31",
        "completion_date": "2027-12-31"
    });
    assert!(!allocation_row_persistable(&row));
}

#[test]
fn allocation_result_persistable_requires_nested_allocations() {
    let ok = json!({
        "field_schedules": [{
            "field_id": "1",
            "allocations": [{
                "crop_id": "7",
                "crop_name": "キャベツ",
                "area_used": 300.0,
                "start_date": "2027-04-21T00:00:00",
                "completion_date": "2027-08-29T00:00:00",
                "growth_days": 131
            }]
        }]
    });
    assert!(allocation_result_persistable(&ok));

    let bare_field = json!({
        "field_schedules": [{
            "field_id": "1",
            "crop_id": "7",
            "start_date": "2026-05-31",
            "completion_date": "2027-12-31",
            "area_used": 1.0
        }]
    });
    assert!(!allocation_result_persistable(&bare_field));
}
