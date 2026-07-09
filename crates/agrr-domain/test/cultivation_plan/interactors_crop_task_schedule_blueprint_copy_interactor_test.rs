// Tests for `interactors/crop_task_schedule_blueprint_copy_interactor.rs`.

use std::collections::HashMap;
use std::sync::Mutex;

use rust_decimal::Decimal;

use crate::cultivation_plan::dtos::{
    CropTaskScheduleBlueprintCopyInput, CropTaskScheduleBlueprintCreateAttrs,
    CropTaskScheduleBlueprintRow,
};
use crate::cultivation_plan::gateways::CropTaskScheduleBlueprintGateway;
use crate::cultivation_plan::interactors::crop_task_schedule_blueprint_copy_interactor::CropTaskScheduleBlueprintCopyInteractor;
use crate::cultivation_plan::interactors::plan_save_test_support::CapturingLogger;
use crate::cultivation_plan::ports::UserAgriculturalTaskMappingPort;

struct MockBlueprintGateway {
    blueprints_by_crop: HashMap<i64, Vec<CropTaskScheduleBlueprintRow>>,
    deleted_crop_ids: Mutex<Vec<i64>>,
    created: Mutex<Vec<CropTaskScheduleBlueprintCreateAttrs>>,
}

impl MockBlueprintGateway {
    fn with_blueprints(crop_id: i64, rows: Vec<CropTaskScheduleBlueprintRow>) -> Self {
        let mut map = HashMap::new();
        map.insert(crop_id, rows);
        Self::from_map(map)
    }

    fn from_map(blueprints_by_crop: HashMap<i64, Vec<CropTaskScheduleBlueprintRow>>) -> Self {
        Self {
            blueprints_by_crop,
            deleted_crop_ids: Mutex::new(vec![]),
            created: Mutex::new(vec![]),
        }
    }

    fn empty() -> Self {
        Self::from_map(HashMap::new())
    }
}

impl CropTaskScheduleBlueprintGateway for MockBlueprintGateway {
    fn list_by_crop_id(
        &self,
        crop_id: i64,
    ) -> Result<Vec<CropTaskScheduleBlueprintRow>, Box<dyn std::error::Error + Send + Sync>> {
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
            .extend(records.iter().cloned());
        Ok(())
    }
}

struct MockTaskMapping {
    mapping: HashMap<i64, i64>,
}

impl UserAgriculturalTaskMappingPort for MockTaskMapping {
    fn user_task_id_for(&self, reference_task_id: Option<i64>) -> Option<i64> {
        reference_task_id.and_then(|id| self.mapping.get(&id).copied())
    }
}

fn sample_blueprint() -> CropTaskScheduleBlueprintRow {
    CropTaskScheduleBlueprintRow {
        agricultural_task_id: Some(10),
        source_agricultural_task_id: Some(10),
        stage_order: 1,
        stage_name: "定植".into(),
        gdd_trigger: Some(Decimal::new(1500, 2)),
        gdd_tolerance: Some(Decimal::new(50, 1)),
        task_type: "field_work".into(),
        source: "reference".into(),
        priority: 2,
        amount: Some(Decimal::new(125, 2)),
        amount_unit: Some("kg".into()),
        description: Some("基肥".into()),
        weather_dependency: Some("dry".into()),
        time_per_sqm: Some(Decimal::new(30, 1)),
    }
}

#[test]
fn call_with_empty_input_is_noop() {
    let gateway = MockBlueprintGateway::empty();
    let mapping = MockTaskMapping {
        mapping: HashMap::new(),
    };
    let logger = CapturingLogger::new();
    let interactor = CropTaskScheduleBlueprintCopyInteractor::new(&gateway, &mapping, &logger);

    interactor
        .call(CropTaskScheduleBlueprintCopyInput {
            reference_crop_id_to_user_crop_id: vec![],
        })
        .expect("empty input");

    assert!(gateway.deleted_crop_ids.lock().unwrap().is_empty());
    assert!(gateway.created.lock().unwrap().is_empty());
}

#[test]
fn skips_pair_when_reference_has_no_blueprints() {
    let gateway = MockBlueprintGateway::empty();
    let mapping = MockTaskMapping {
        mapping: HashMap::new(),
    };
    let logger = CapturingLogger::new();
    let interactor = CropTaskScheduleBlueprintCopyInteractor::new(&gateway, &mapping, &logger);

    interactor
        .call(CropTaskScheduleBlueprintCopyInput::from_map([(99, 200)]))
        .expect("no blueprints");

    assert!(gateway.deleted_crop_ids.lock().unwrap().is_empty());
    assert!(gateway.created.lock().unwrap().is_empty());
}

#[test]
fn copies_blueprints_with_mapped_task_ids_and_normalized_decimals() {
    let gateway = MockBlueprintGateway::with_blueprints(10, vec![sample_blueprint()]);
    let mut mapping = HashMap::new();
    mapping.insert(10, 501);
    let task_mapping = MockTaskMapping { mapping };
    let logger = CapturingLogger::new();
    let interactor =
        CropTaskScheduleBlueprintCopyInteractor::new(&gateway, &task_mapping, &logger);

    interactor
        .call(CropTaskScheduleBlueprintCopyInput::from_map([(10, 200)]))
        .expect("copy");

    assert_eq!(*gateway.deleted_crop_ids.lock().unwrap(), vec![200]);
    let created = gateway.created.lock().unwrap();
    assert_eq!(1, created.len());
    let record = &created[0];
    assert_eq!(200, record.crop_id);
    assert_eq!(Some(501), record.agricultural_task_id);
    assert_eq!(Some(10), record.source_agricultural_task_id);
    assert_eq!("定植", record.stage_name);
    assert_eq!(Some("15".into()), record.gdd_trigger);
    assert_eq!(Some("5".into()), record.gdd_tolerance);
    assert_eq!(Some("1.25".into()), record.amount);
    assert_eq!(Some("3".into()), record.time_per_sqm);
}

#[test]
fn uses_source_agricultural_task_id_when_agricultural_task_id_missing() {
    let mut blueprint = sample_blueprint();
    blueprint.agricultural_task_id = None;
    blueprint.source_agricultural_task_id = Some(77);
    let gateway = MockBlueprintGateway::with_blueprints(10, vec![blueprint]);
    let mut mapping = HashMap::new();
    mapping.insert(77, 888);
    let task_mapping = MockTaskMapping { mapping };
    let logger = CapturingLogger::new();
    let interactor =
        CropTaskScheduleBlueprintCopyInteractor::new(&gateway, &task_mapping, &logger);

    interactor
        .call(CropTaskScheduleBlueprintCopyInput::from_map([(10, 200)]))
        .expect("copy");

    let created = gateway.created.lock().unwrap();
    assert_eq!(Some(888), created[0].agricultural_task_id);
    assert_eq!(Some(77), created[0].source_agricultural_task_id);
}

#[test]
fn processes_multiple_reference_to_user_pairs() {
    let mut blueprints_by_crop = HashMap::new();
    blueprints_by_crop.insert(10, vec![sample_blueprint()]);
    blueprints_by_crop.insert(
        11,
        vec![CropTaskScheduleBlueprintRow {
            stage_name: "収穫".into(),
            stage_order: 2,
            task_type: "field_work".into(),
            source: "reference".into(),
            priority: 1,
            agricultural_task_id: None,
            source_agricultural_task_id: None,
            gdd_trigger: None,
            gdd_tolerance: None,
            amount: None,
            amount_unit: None,
            description: None,
            weather_dependency: None,
            time_per_sqm: None,
        }],
    );
    let gateway = MockBlueprintGateway::from_map(blueprints_by_crop);
    let task_mapping = MockTaskMapping {
        mapping: HashMap::new(),
    };
    let logger = CapturingLogger::new();
    let interactor =
        CropTaskScheduleBlueprintCopyInteractor::new(&gateway, &task_mapping, &logger);

    interactor
        .call(CropTaskScheduleBlueprintCopyInput::from_map([(10, 201), (11, 202)]))
        .expect("copy pairs");

    let deleted = gateway.deleted_crop_ids.lock().unwrap();
    assert_eq!(vec![201, 202], *deleted);
    assert_eq!(2, gateway.created.lock().unwrap().len());
}
