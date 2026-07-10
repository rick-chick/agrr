// Tests for `interactors/crop_task_schedule_blueprint_copy_interactor.rs`.

use crate::cultivation_plan::dtos::{
    CropTaskScheduleBlueprintCopyInput, CropTaskScheduleBlueprintCreateAttrs,
    CropTaskScheduleBlueprintRow,
};
use crate::cultivation_plan::gateways::CropTaskScheduleBlueprintGateway;
use crate::cultivation_plan::interactors::plan_save_test_support::CapturingLogger;
use crate::cultivation_plan::ports::UserAgriculturalTaskMappingPort;
use rust_decimal::Decimal;
use std::collections::HashMap;
use std::str::FromStr;
use std::sync::Mutex;

struct CapturingBlueprintGateway {
    blueprints_by_crop: HashMap<i64, Vec<CropTaskScheduleBlueprintRow>>,
    listed_crop_ids: Mutex<Vec<i64>>,
    deleted_crop_ids: Mutex<Vec<i64>>,
    created: Mutex<Vec<Vec<CropTaskScheduleBlueprintCreateAttrs>>>,
}

impl CapturingBlueprintGateway {
    fn with_blueprints(crop_id: i64, rows: Vec<CropTaskScheduleBlueprintRow>) -> Self {
        let mut blueprints_by_crop = HashMap::new();
        blueprints_by_crop.insert(crop_id, rows);
        Self {
            blueprints_by_crop,
            listed_crop_ids: Mutex::new(vec![]),
            deleted_crop_ids: Mutex::new(vec![]),
            created: Mutex::new(vec![]),
        }
    }

    fn empty() -> Self {
        Self {
            blueprints_by_crop: HashMap::new(),
            listed_crop_ids: Mutex::new(vec![]),
            deleted_crop_ids: Mutex::new(vec![]),
            created: Mutex::new(vec![]),
        }
    }
}

impl CropTaskScheduleBlueprintGateway for CapturingBlueprintGateway {
    fn list_by_crop_id(
        &self,
        crop_id: i64,
    ) -> Result<Vec<CropTaskScheduleBlueprintRow>, Box<dyn std::error::Error + Send + Sync>> {
        self.listed_crop_ids.lock().unwrap().push(crop_id);
        Ok(self
            .blueprints_by_crop
            .get(&crop_id)
            .cloned()
            .unwrap_or_default())
    }

    fn delete_by_crop_id(
        &self,
        crop_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.deleted_crop_ids.lock().unwrap().push(crop_id);
        Ok(())
    }

    fn bulk_create(
        &self,
        records: &[CropTaskScheduleBlueprintCreateAttrs],
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.created
            .lock()
            .unwrap()
            .push(records.to_vec());
        Ok(())
    }
}

struct MockTaskMapping {
    map: HashMap<i64, i64>,
}

impl UserAgriculturalTaskMappingPort for MockTaskMapping {
    fn user_task_id_for(&self, reference_task_id: Option<i64>) -> Option<i64> {
        reference_task_id.and_then(|id| self.map.get(&id).copied())
    }
}

fn dec(s: &str) -> Decimal {
    Decimal::from_str(s).unwrap()
}

fn sample_blueprint_row() -> CropTaskScheduleBlueprintRow {
    CropTaskScheduleBlueprintRow {
        agricultural_task_id: Some(100),
        source_agricultural_task_id: Some(50),
        stage_order: 1,
        stage_name: "定植前".into(),
        gdd_trigger: Some(dec("0.0")),
        gdd_tolerance: Some(dec("5.0")),
        task_type: "field_work".into(),
        source: "agrr_schedule".into(),
        priority: 1,
        amount: Some(dec("4.00")),
        amount_unit: Some("g/m2".into()),
        description: Some("土壌準備".into()),
        weather_dependency: Some("low".into()),
        time_per_sqm: Some(dec("0.10")),
    }
}

#[test]
fn call_noops_when_input_is_empty() {
    let gateway = CapturingBlueprintGateway::empty();
    let mapping = MockTaskMapping { map: HashMap::new() };
    let logger = CapturingLogger::new();
    let interactor =
        CropTaskScheduleBlueprintCopyInteractor::new(&gateway, &mapping, &logger);

    interactor
        .call(CropTaskScheduleBlueprintCopyInput::from_map([]))
        .expect("empty input");

    assert!(gateway.listed_crop_ids.lock().unwrap().is_empty());
    assert!(gateway.deleted_crop_ids.lock().unwrap().is_empty());
    assert!(gateway.created.lock().unwrap().is_empty());
}

#[test]
fn call_skips_pair_when_reference_crop_has_no_blueprints() {
    let gateway = CapturingBlueprintGateway::empty();
    let mapping = MockTaskMapping { map: HashMap::new() };
    let logger = CapturingLogger::new();
    let interactor =
        CropTaskScheduleBlueprintCopyInteractor::new(&gateway, &mapping, &logger);

    interactor
        .call(CropTaskScheduleBlueprintCopyInput::from_map([(10, 20)]))
        .expect("no blueprints");

    assert_eq!(*gateway.listed_crop_ids.lock().unwrap(), vec![10]);
    assert!(gateway.deleted_crop_ids.lock().unwrap().is_empty());
    assert!(gateway.created.lock().unwrap().is_empty());
}

#[test]
fn call_replaces_user_crop_blueprints_with_mapped_tasks() {
    let gateway = CapturingBlueprintGateway::with_blueprints(10, vec![sample_blueprint_row()]);
    let mut map = HashMap::new();
    map.insert(50, 500);
    let mapping = MockTaskMapping { map };
    let logger = CapturingLogger::new();
    let interactor =
        CropTaskScheduleBlueprintCopyInteractor::new(&gateway, &mapping, &logger);

    interactor
        .call(CropTaskScheduleBlueprintCopyInput::from_map([(10, 20)]))
        .expect("copy");

    assert_eq!(*gateway.deleted_crop_ids.lock().unwrap(), vec![20]);
    let created = gateway.created.lock().unwrap();
    assert_eq!(created.len(), 1);
    let record = &created[0][0];
    assert_eq!(record.crop_id, 20);
    assert_eq!(record.agricultural_task_id, Some(500));
    assert_eq!(record.source_agricultural_task_id, Some(50));
    assert_eq!(record.stage_name, "定植前");
    assert_eq!(record.task_type, "field_work");
}

#[test]
fn call_uses_agricultural_task_id_when_source_task_id_is_missing() {
    let mut row = sample_blueprint_row();
    row.source_agricultural_task_id = None;
    row.agricultural_task_id = Some(77);
    let gateway = CapturingBlueprintGateway::with_blueprints(10, vec![row]);
    let mut map = HashMap::new();
    map.insert(77, 770);
    let mapping = MockTaskMapping { map };
    let logger = CapturingLogger::new();
    let interactor =
        CropTaskScheduleBlueprintCopyInteractor::new(&gateway, &mapping, &logger);

    interactor
        .call(CropTaskScheduleBlueprintCopyInput::from_map([(10, 20)]))
        .expect("copy");

    let record = &gateway.created.lock().unwrap()[0][0];
    assert_eq!(record.agricultural_task_id, Some(770));
    assert_eq!(record.source_agricultural_task_id, Some(77));
}

#[test]
fn call_normalizes_decimal_fields_to_strings() {
    let gateway = CapturingBlueprintGateway::with_blueprints(10, vec![sample_blueprint_row()]);
    let mapping = MockTaskMapping { map: HashMap::new() };
    let logger = CapturingLogger::new();
    let interactor =
        CropTaskScheduleBlueprintCopyInteractor::new(&gateway, &mapping, &logger);

    interactor
        .call(CropTaskScheduleBlueprintCopyInput::from_map([(10, 20)]))
        .expect("copy");

    let record = &gateway.created.lock().unwrap()[0][0];
    assert_eq!(record.gdd_trigger.as_deref(), Some("0"));
    assert_eq!(record.gdd_tolerance.as_deref(), Some("5"));
    assert_eq!(record.amount.as_deref(), Some("4"));
    assert_eq!(record.time_per_sqm.as_deref(), Some("0.1"));
}

#[test]
fn call_copies_multiple_reference_to_user_crop_pairs() {
    let mut blueprints_by_crop = HashMap::new();
    blueprints_by_crop.insert(10, vec![sample_blueprint_row()]);
    blueprints_by_crop.insert(
        11,
        vec![CropTaskScheduleBlueprintRow {
            stage_name: "追肥".into(),
            task_type: "topdress_fertilization".into(),
            ..sample_blueprint_row()
        }],
    );
    let gateway = CapturingBlueprintGateway {
        blueprints_by_crop,
        listed_crop_ids: Mutex::new(vec![]),
        deleted_crop_ids: Mutex::new(vec![]),
        created: Mutex::new(vec![]),
    };
    let mapping = MockTaskMapping { map: HashMap::new() };
    let logger = CapturingLogger::new();
    let interactor =
        CropTaskScheduleBlueprintCopyInteractor::new(&gateway, &mapping, &logger);

    interactor
        .call(CropTaskScheduleBlueprintCopyInput::from_map([(10, 20), (11, 21)]))
        .expect("multi copy");

    assert_eq!(*gateway.listed_crop_ids.lock().unwrap(), vec![10, 11]);
    assert_eq!(*gateway.deleted_crop_ids.lock().unwrap(), vec![20, 21]);
    let created = gateway.created.lock().unwrap();
    assert_eq!(created.len(), 2);
    assert_eq!(created[0][0].crop_id, 20);
    assert_eq!(created[1][0].crop_id, 21);
    assert_eq!(created[1][0].stage_name, "追肥");
}
