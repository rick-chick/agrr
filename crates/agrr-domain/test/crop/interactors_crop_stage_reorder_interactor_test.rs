// Tests for `interactors/crop_stage_reorder_interactor.rs`

use crate::crop::dtos::{CropStageListOutput, CropStageOrderEntry, CropStageReorderInput};
use crate::crop::entities::CropStageEntity;
use crate::crop::gateways::CropStageReorderGateway;
use crate::crop::interactors::crop_stage_reorder_interactor::CropStageReorderInteractor;
use crate::crop::ports::{CropStageReorderFailure, CropStageReorderOutputPort};
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};

struct SpyOutput {
    success: Option<CropStageListOutput>,
    failure: Option<CropStageReorderFailure>,
}

impl CropStageReorderOutputPort for SpyOutput {
    fn on_success(&mut self, output: CropStageListOutput) {
        self.success = Some(output);
    }

    fn on_failure(&mut self, error: CropStageReorderFailure) {
        self.failure = Some(error);
    }
}

struct ReorderGateway {
    ok: Option<Vec<CropStageEntity>>,
    invalid: bool,
    not_found: bool,
    boom: bool,
    last_crop_id: std::sync::Mutex<Option<i64>>,
    last_orders: std::sync::Mutex<Option<Vec<(i64, i64)>>>,
}

impl CropStageReorderGateway for ReorderGateway {
    fn reorder_crop_stages(
        &self,
        crop_id: i64,
        orders: &[(i64, i64)],
    ) -> Result<Vec<CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> {
        *self.last_crop_id.lock().unwrap() = Some(crop_id);
        *self.last_orders.lock().unwrap() = Some(orders.to_vec());
        if self.boom {
            return Err("reorder failed".into());
        }
        if self.not_found {
            return Err(Box::new(RecordNotFoundError));
        }
        if self.invalid {
            return Err(Box::new(RecordInvalidError::new(
                Some("invalid order".into()),
                None,
            )));
        }
        Ok(self.ok.clone().unwrap_or_default())
    }
}

#[test]
fn calls_on_success_with_reordered_stages() {
    let gateway = ReorderGateway {
        ok: Some(vec![CropStageEntity {
            id: 2,
            crop_id: 10,
            name: "B".into(),
            order: 1,
            temperature_requirement: None,
            thermal_requirement: None,
            sunshine_requirement: None,
            nutrient_requirement: None,
            created_at: Some("t".into()),
            updated_at: Some("t".into()),
        }]),
        invalid: false,
        not_found: false,
        boom: false,
        last_crop_id: std::sync::Mutex::new(None),
        last_orders: std::sync::Mutex::new(None),
    };
    let mut output = SpyOutput {
        success: None,
        failure: None,
    };
    let mut interactor = CropStageReorderInteractor::new(&mut output, &gateway);
    let input = CropStageReorderInput::new(
        10,
        vec![
            CropStageOrderEntry {
                stage_id: 2,
                order: 1,
            },
            CropStageOrderEntry {
                stage_id: 1,
                order: 2,
            },
        ],
    );

    interactor.call(input).unwrap();

    assert!(output.success.is_some());
    assert_eq!(output.success.unwrap().stages.len(), 1);
    assert_eq!(*gateway.last_crop_id.lock().unwrap(), Some(10));
    assert_eq!(
        *gateway.last_orders.lock().unwrap(),
        Some(vec![(2, 1), (1, 2)])
    );
}

#[test]
fn rejects_empty_orders_without_calling_gateway() {
    let gateway = ReorderGateway {
        ok: None,
        invalid: false,
        not_found: false,
        boom: false,
        last_crop_id: std::sync::Mutex::new(None),
        last_orders: std::sync::Mutex::new(None),
    };
    let mut output = SpyOutput {
        success: None,
        failure: None,
    };
    let mut interactor = CropStageReorderInteractor::new(&mut output, &gateway);

    interactor
        .call(CropStageReorderInput::new(10, vec![]))
        .unwrap();

    assert!(matches!(
        output.failure,
        Some(CropStageReorderFailure::Error(_))
    ));
    assert!(gateway.last_crop_id.lock().unwrap().is_none());
}

#[test]
fn maps_record_invalid_to_failure() {
    let gateway = ReorderGateway {
        ok: None,
        invalid: true,
        not_found: false,
        boom: false,
        last_crop_id: std::sync::Mutex::new(None),
        last_orders: std::sync::Mutex::new(None),
    };
    let mut output = SpyOutput {
        success: None,
        failure: None,
    };
    let mut interactor = CropStageReorderInteractor::new(&mut output, &gateway);

    interactor
        .call(CropStageReorderInput::new(
            10,
            vec![CropStageOrderEntry {
                stage_id: 1,
                order: 1,
            }],
        ))
        .unwrap();

    assert!(matches!(
        output.failure,
        Some(CropStageReorderFailure::Error(_))
    ));
}
