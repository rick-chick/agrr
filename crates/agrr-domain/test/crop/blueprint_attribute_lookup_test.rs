// Tests for `mappers/blueprint_attribute_lookup.rs`.

use crate::agricultural_task::entities::AgriculturalTaskEntity;
use crate::crop::dtos::MastersCropTaskScheduleBlueprint;
use rust_decimal::Decimal;
use std::str::FromStr;

fn sample_blueprint(
    task_id: i64,
    description: Option<&str>,
    weather_dependency: Option<&str>,
    time_per_sqm: Option<Decimal>,
) -> MastersCropTaskScheduleBlueprint {
    MastersCropTaskScheduleBlueprint {
        id: 1,
        crop_id: 2,
        agricultural_task_id: Some(task_id),
        source_agricultural_task_id: None,
        stage_order: None,
        stage_name: None,
        gdd_trigger: None,
        gdd_tolerance: None,
        task_type: "field_work".into(),
        source: "manual".into(),
        priority: 1,
        amount: None,
        amount_unit: None,
        description: description.map(str::to_string),
        weather_dependency: weather_dependency.map(str::to_string),
        time_per_sqm,
        name: None,
        created_at: None,
        updated_at: None,
    }
}

fn sample_task(
    id: i64,
    description: Option<&str>,
    weather_dependency: Option<&str>,
    time_per_sqm: Option<f64>,
) -> AgriculturalTaskEntity {
    AgriculturalTaskEntity {
        id: Some(id),
        user_id: Some(1),
        name: "task".into(),
        description: description.map(str::to_string),
        time_per_sqm,
        weather_dependency: weather_dependency.map(str::to_string),
        required_tools: vec![],
        skill_level: None,
        region: None,
        task_type: Some("field_work".into()),
        is_reference: false,
        created_at: None,
        updated_at: None,
    }
}

#[test]
fn merge_blueprint_task_attributes_prefers_blueprint_fields_over_task_master() {
    let blueprint = sample_blueprint(
        42,
        Some("bp desc"),
        Some("high"),
        Some(Decimal::from_str("2.0").unwrap()),
    );
    let task = sample_task(42, Some("task desc"), Some("low"), Some(0.5));

    let snapshot = merge_blueprint_task_attributes(&blueprint, Some(&task));

    assert_eq!(snapshot.description.as_deref(), Some("bp desc"));
    assert_eq!(snapshot.weather_dependency.as_deref(), Some("high"));
    assert_eq!(
        snapshot.time_per_sqm,
        Some(Decimal::from_str("2.0").unwrap())
    );
}

#[test]
fn merge_blueprint_task_attributes_falls_back_to_task_master_when_blueprint_empty() {
    let blueprint = sample_blueprint(42, None, None, None);
    let task = sample_task(42, Some("task desc"), Some("low"), Some(0.5));

    let snapshot = merge_blueprint_task_attributes(&blueprint, Some(&task));

    assert_eq!(snapshot.description.as_deref(), Some("task desc"));
    assert_eq!(snapshot.weather_dependency.as_deref(), Some("low"));
    assert_eq!(snapshot.time_per_sqm, Some(Decimal::from_str("0.5").unwrap()));
}

#[test]
fn build_attribute_lookup_prefers_blueprint_fields_over_task_master() {
    let blueprints = vec![sample_blueprint(
        42,
        Some("bp desc"),
        Some("high"),
        Some(Decimal::from_str("2.0").unwrap()),
    )];
    let tasks = vec![sample_task(42, Some("task desc"), Some("low"), Some(0.5))];

    let lookup = build_attribute_lookup(&blueprints, &tasks);

    let snapshot = lookup.get(&42).expect("task 42");
    assert_eq!(snapshot.description.as_deref(), Some("bp desc"));
    assert_eq!(snapshot.weather_dependency.as_deref(), Some("high"));
    assert_eq!(snapshot.time_per_sqm, Some(Decimal::from_str("2.0").unwrap()));
}

#[test]
fn build_attribute_lookup_falls_back_to_task_master_when_blueprint_empty() {
    let blueprints = vec![sample_blueprint(42, None, None, None)];
    let tasks = vec![sample_task(42, Some("task desc"), Some("low"), Some(0.5))];

    let lookup = build_attribute_lookup(&blueprints, &tasks);

    let snapshot = lookup.get(&42).expect("task 42");
    assert_eq!(snapshot.description.as_deref(), Some("task desc"));
    assert_eq!(snapshot.weather_dependency.as_deref(), Some("low"));
    assert_eq!(snapshot.time_per_sqm, Some(Decimal::from_str("0.5").unwrap()));
}

#[test]
fn build_attribute_lookup_skips_blueprints_without_agricultural_task_id() {
    let mut blueprint = sample_blueprint(42, Some("desc"), None, None);
    blueprint.agricultural_task_id = None;

    let lookup = build_attribute_lookup(&[blueprint], &[]);

    assert!(lookup.is_empty());
}
