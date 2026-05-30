//! add_crop edge adapters (crop resolve, adjust result collector).

use agrr_adapters_sqlite::{CropSqliteGateway, UserLookupSqliteGateway};
use agrr_domain::crop::dtos::AddCropCropSnapshot;
use agrr_domain::crop::entities::CropEntity;
use agrr_domain::crop::interactors::crop_find_public_plan_add_crop_record_interactor::{
    CropFindPublicPlanAddCropRecordInteractor, CropFindPublicPlanAddCropRecordOutputPort,
};
use agrr_domain::crop::interactors::crop_find_user_non_reference_record_interactor::{
    CropFindUserNonReferenceRecordInteractor, CropFindUserNonReferenceRecordOutputPort,
};
use agrr_domain::cultivation_plan::dtos::{
    AddCropAdjustResult, PlanAllocationAdjustFailure, PlanAllocationAdjustOutput,
};
use agrr_domain::cultivation_plan::ports::{
    AddCropAdjustResultSink, AddCropCropResolveInputPort, PlanAllocationAdjustOutputPort,
};
use agrr_domain::shared::dtos::Error;
use std::sync::Mutex;

use crate::adapters::NoopLogger;

pub struct AddCropCropResolvePrivate<'a> {
    crop_gateway: &'a CropSqliteGateway,
    user_id: i64,
    user_lookup: &'a UserLookupSqliteGateway,
    logger: &'a NoopLogger,
}

impl<'a> AddCropCropResolvePrivate<'a> {
    pub fn new(
        crop_gateway: &'a CropSqliteGateway,
        user_id: i64,
        user_lookup: &'a UserLookupSqliteGateway,
    ) -> Self {
        Self {
            crop_gateway,
            user_id,
            user_lookup,
            logger: &NoopLogger,
        }
    }
}

struct CropResolveCollector {
    crop: Option<CropEntity>,
}

impl CropFindPublicPlanAddCropRecordOutputPort for CropResolveCollector {
    fn on_success(&mut self, crop: CropEntity) {
        self.crop = Some(crop);
    }

    fn on_failure(&mut self, _error: Error) {
        self.crop = None;
    }
}

impl CropFindUserNonReferenceRecordOutputPort for CropResolveCollector {
    fn on_success(&mut self, entity: CropEntity) {
        self.crop = Some(entity);
    }

    fn on_failure(&mut self, _error: Error) {
        self.crop = None;
    }
}

fn to_snapshot(entity: &CropEntity) -> AddCropCropSnapshot {
    AddCropCropSnapshot {
        id: entity.id,
        name: entity.name.clone(),
        variety: entity.variety.clone(),
        area_per_unit: entity.area_per_unit.unwrap_or(0.0),
        revenue_per_area: entity.revenue_per_area.unwrap_or(0.0),
    }
}

pub struct AddCropCropResolvePublic<'a> {
    crop_gateway: &'a CropSqliteGateway,
    logger: &'a NoopLogger,
}

impl<'a> AddCropCropResolvePublic<'a> {
    pub fn new(crop_gateway: &'a CropSqliteGateway) -> Self {
        Self {
            crop_gateway,
            logger: &NoopLogger,
        }
    }
}

impl AddCropCropResolveInputPort for AddCropCropResolvePublic<'_> {
    fn call(&self, crop_id: &str) -> Option<AddCropCropSnapshot> {
        let crop_id: i64 = crop_id.parse().ok()?;
        let mut collector = CropResolveCollector { crop: None };
        let mut interactor = CropFindPublicPlanAddCropRecordInteractor::new(
            &mut collector,
            self.crop_gateway,
            self.logger,
        );
        interactor.call(crop_id).ok()?;
        collector.crop.as_ref().map(to_snapshot)
    }
}

impl AddCropCropResolveInputPort for AddCropCropResolvePrivate<'_> {
    fn call(&self, crop_id: &str) -> Option<AddCropCropSnapshot> {
        let crop_id: i64 = crop_id.parse().ok()?;
        let mut collector = CropResolveCollector { crop: None };
        let mut interactor = CropFindUserNonReferenceRecordInteractor::new(
            &mut collector,
            self.user_id,
            self.crop_gateway,
            self.logger,
            self.user_lookup,
        );
        interactor.call(crop_id).ok()?;
        collector.crop.as_ref().map(to_snapshot)
    }
}

pub(crate) struct AdjustResultCell {
    result: Mutex<Option<AddCropAdjustResult>>,
}

impl AdjustResultCell {
    fn new() -> Self {
        Self {
            result: Mutex::new(None),
        }
    }
}

/// Shared adjust output + add_crop sink (RefCell avoids overlapping `&mut` borrows in AddCropInteractor).
pub struct AddCropAdjustResultCollector {
    pub(crate) inner: AdjustResultCell,
}

impl AddCropAdjustResultCollector {
    pub fn new() -> Self {
        Self {
            inner: AdjustResultCell::new(),
        }
    }
}

impl Default for AddCropAdjustResultCollector {
    fn default() -> Self {
        Self::new()
    }
}

pub struct AddCropAdjustOutputAdapter<'a> {
    cell: &'a AdjustResultCell,
}

impl AddCropAdjustResultCollector {
    pub fn output_adapter(&self) -> AddCropAdjustOutputAdapter<'_> {
        AddCropAdjustOutputAdapter {
            cell: &self.inner,
        }
    }
}

impl PlanAllocationAdjustOutputPort for AddCropAdjustOutputAdapter<'_> {
    fn on_success(&mut self, _output: PlanAllocationAdjustOutput) {
        *self.cell.result.lock().unwrap() = Some(AddCropAdjustResult::success());
    }

    fn on_failure(&mut self, failure: PlanAllocationAdjustFailure) {
        let status = match failure.kind.as_str() {
            PlanAllocationAdjustFailure::KIND_NOT_FOUND
            | PlanAllocationAdjustFailure::KIND_NO_WEATHER_LOCATION => 404,
            PlanAllocationAdjustFailure::KIND_INVALID_DATE
            | PlanAllocationAdjustFailure::KIND_CROP_MISSING_GROWTH_STAGES => 400,
            _ => 500,
        };
        *self.cell.result.lock().unwrap() = Some(AddCropAdjustResult::failure(
            failure.message,
            Some(status),
        ));
    }
}

impl AddCropAdjustResultSink for AddCropAdjustResultCollector {
    fn add_crop_adjust_result(&self) -> AddCropAdjustResult {
        self.inner
            .result
            .lock()
            .unwrap()
            .clone()
            .unwrap_or_else(|| AddCropAdjustResult::failure("no adjust response", Some(500)))
    }
}
