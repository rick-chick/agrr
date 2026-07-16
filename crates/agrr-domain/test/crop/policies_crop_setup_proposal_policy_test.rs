use serde_json::json;

use crate::crop::policies::crop_setup_proposal_policy::validate_and_normalize;

#[test]
fn validate_rejects_missing_required_gdd() {
    let body = json!({
        "stages": [{
            "name": "育苗",
            "order": 1,
            "thermal_requirement": {}
        }],
        "agricultural_tasks": [{
            "ref": "task-weeding",
            "name": "除草",
            "task_type": "field_work",
            "region": "jp"
        }],
        "task_schedule_blueprints": [{
            "agricultural_task_ref": "task-weeding",
            "stage_order": 1,
            "gdd_trigger": 0,
            "task_type": "field_work",
            "priority": 1
        }]
    });

    let errors = validate_and_normalize(&body, &[], &[]).unwrap_err();
    assert!(
        errors
            .iter()
            .any(|e| e.path.contains("required_gdd")),
        "{errors:?}"
    );
}

#[test]
fn validate_accepts_minimal_proposal() {
    let body = json!({
        "stages": [{
            "name": "育苗",
            "order": 1,
            "thermal_requirement": { "required_gdd": "120" }
        }],
        "agricultural_tasks": [{
            "ref": "task-weeding",
            "name": "除草",
            "task_type": "field_work",
            "region": "jp"
        }],
        "task_schedule_blueprints": [{
            "agricultural_task_ref": "task-weeding",
            "stage_order": 1,
            "stage_name": "育苗",
            "gdd_trigger": 0,
            "task_type": "field_work",
            "priority": 1
        }]
    });

    let (plan, normalized) = validate_and_normalize(&body, &[], &[]).expect("valid proposal");
    assert_eq!(1, plan.stages.len());
    assert_eq!("育苗", plan.stages[0].name);
    assert_eq!(1, normalized["stages"].as_array().unwrap().len());
}

#[test]
fn validate_rejects_unknown_task_ref_in_blueprint() {
    let body = json!({
        "stages": [{
            "name": "育苗",
            "order": 1,
            "thermal_requirement": { "required_gdd": "120" }
        }],
        "agricultural_tasks": [{
            "ref": "task-weeding",
            "name": "除草",
            "task_type": "field_work",
            "region": "jp"
        }],
        "task_schedule_blueprints": [{
            "agricultural_task_ref": "missing-ref",
            "stage_order": 1,
            "gdd_trigger": 0,
            "task_type": "field_work"
        }]
    });

    let errors = validate_and_normalize(&body, &[], &[]).unwrap_err();
    assert!(
        errors
            .iter()
            .any(|e| e.path.contains("agricultural_task_ref")),
        "{errors:?}"
    );
}
