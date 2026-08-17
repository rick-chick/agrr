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
fn validate_accepts_pest_control_task_types() {
    let body = json!({
        "stages": [{
            "name": "生育期",
            "order": 1,
            "thermal_requirement": { "required_gdd": "120" }
        }],
        "agricultural_tasks": [{
            "ref": "task-preventive",
            "name": "予防散布",
            "task_type": "preventive_spray",
            "region": "jp"
        }],
        "task_schedule_blueprints": [{
            "agricultural_task_ref": "task-preventive",
            "stage_order": 1,
            "stage_name": "生育期",
            "gdd_trigger": 0,
            "task_type": "preventive_spray",
            "priority": 1
        }]
    });

    let (plan, _normalized) = validate_and_normalize(&body, &[], &[]).expect("valid proposal");
    assert_eq!("preventive_spray", plan.agricultural_tasks[0].task_type);
    assert_eq!("preventive_spray", plan.task_schedule_blueprints[0].task_type);
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

#[test]
fn validate_accepts_blueprint_timing_patch_intent() {
    use crate::crop::dtos::MastersCropTaskScheduleBlueprint;
    use rust_decimal::Decimal;

    let existing = vec![MastersCropTaskScheduleBlueprint {
        id: 99,
        crop_id: 1,
        agricultural_task_id: Some(10),
        source_agricultural_task_id: None,
        stage_order: Some(1),
        stage_name: Some("育苗".into()),
        gdd_trigger: Some(Decimal::from(120)),
        gdd_tolerance: None,
        task_type: "field_work".into(),
        source: "manual".into(),
        priority: 1,
        amount: None,
        amount_unit: None,
        description: None,
        weather_dependency: None,
        time_per_sqm: None,
        name: Some("除草".into()),
        created_at: None,
        updated_at: None,
    }];

    let body = json!({
        "intent": "blueprint_timing_patch",
        "task_schedule_blueprints": [{
            "blueprint_id": 99,
            "gdd_trigger": 130.0
        }]
    });

    let (plan, normalized) = validate_and_normalize(&body, &existing, &[]).expect("valid patch");
    assert_eq!(Some("blueprint_timing_patch".to_string()), plan.intent);
    assert_eq!(1, plan.blueprint_timing_patches.len());
    assert_eq!(99, plan.blueprint_timing_patches[0].blueprint_id);
    assert_eq!(
        "blueprint_timing_patch",
        normalized["intent"].as_str().unwrap()
    );
}

#[test]
fn validate_accepts_blueprint_amount_patch_intent() {
    use crate::crop::dtos::MastersCropTaskScheduleBlueprint;
    use rust_decimal::Decimal;

    let existing = vec![MastersCropTaskScheduleBlueprint {
        id: 42,
        crop_id: 1,
        agricultural_task_id: Some(10),
        source_agricultural_task_id: None,
        stage_order: Some(1),
        stage_name: Some("追肥".into()),
        gdd_trigger: Some(Decimal::from(200)),
        gdd_tolerance: None,
        task_type: "topdress_fertilization".into(),
        source: "manual".into(),
        priority: 1,
        amount: Some(Decimal::from(2)),
        amount_unit: Some("kg".into()),
        description: None,
        weather_dependency: None,
        time_per_sqm: None,
        name: Some("追肥".into()),
        created_at: None,
        updated_at: None,
    }];

    let body = json!({
        "intent": "blueprint_amount_patch",
        "task_schedule_blueprints": [{
            "blueprint_id": 42,
            "amount": 2.5,
            "amount_unit": "kg"
        }]
    });

    let (plan, normalized) = validate_and_normalize(&body, &existing, &[]).expect("valid patch");
    assert_eq!(Some("blueprint_amount_patch".to_string()), plan.intent);
    assert_eq!(1, plan.blueprint_amount_patches.len());
    assert_eq!(42, plan.blueprint_amount_patches[0].blueprint_id);
    assert_eq!(2.5, plan.blueprint_amount_patches[0].amount);
    assert_eq!(
        Some("kg".to_string()),
        plan.blueprint_amount_patches[0].amount_unit
    );
    assert_eq!(
        "blueprint_amount_patch",
        normalized["intent"].as_str().unwrap()
    );
}
