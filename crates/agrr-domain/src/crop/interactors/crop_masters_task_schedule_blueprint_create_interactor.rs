//! Ruby: `Domain::Crop::Interactors::CropMastersTaskScheduleBlueprintCreateInteractor`

use crate::agricultural_task::gateways::AgriculturalTaskGateway;
use crate::crop::dtos::{
    MastersCropTaskScheduleBlueprintCreateFailure,
    MastersCropTaskScheduleBlueprintCreateFailureReason,
    MastersCropTaskScheduleBlueprintCreateInput,
};
use crate::crop::gateways::{CropGateway, CropMastersTaskScheduleBlueprintGateway};
use crate::crop::policies::{
    crop_masters_crop_edit_access, masters_crop_task_schedule_blueprint_create_policy,
};
use crate::crop::ports::CropMastersTaskScheduleBlueprintCreateOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;

pub struct CropMastersTaskScheduleBlueprintCreateInteractor<'a, G, AG, BG, O, U> {
    output_port: &'a mut O,
    crop_gateway: &'a G,
    agricultural_task_gateway: &'a AG,
    blueprint_gateway: &'a BG,
    user_lookup: &'a U,
}

impl<'a, G, AG, BG, O, U> CropMastersTaskScheduleBlueprintCreateInteractor<'a, G, AG, BG, O, U>
where
    G: CropGateway,
    AG: AgriculturalTaskGateway,
    BG: CropMastersTaskScheduleBlueprintGateway,
    O: CropMastersTaskScheduleBlueprintCreateOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        crop_gateway: &'a G,
        agricultural_task_gateway: &'a AG,
        blueprint_gateway: &'a BG,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            crop_gateway,
            agricultural_task_gateway,
            blueprint_gateway,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        input: MastersCropTaskScheduleBlueprintCreateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let task_id = match input.agricultural_task_id {
            Some(id) if id > 0 => id,
            _ => {
                self.output_port.on_failure(MastersCropTaskScheduleBlueprintCreateFailure::new(
                    MastersCropTaskScheduleBlueprintCreateFailureReason::MissingAgriculturalTaskId,
                ));
                return Ok(());
            }
        };

        let stage_order = match input.stage_order {
            Some(order) if order <= 0 => {
                self.output_port.on_failure(MastersCropTaskScheduleBlueprintCreateFailure::new(
                    MastersCropTaskScheduleBlueprintCreateFailureReason::InvalidStageOrder,
                ));
                return Ok(());
            }
            other => other,
        };

        let gdd_trigger = match input.gdd_trigger {
            Some(value) if !value.is_finite() || value < 0.0 => {
                self.output_port.on_failure(MastersCropTaskScheduleBlueprintCreateFailure::new(
                    MastersCropTaskScheduleBlueprintCreateFailureReason::MissingGddTrigger,
                ));
                return Ok(());
            }
            other => other,
        };

        let user = self.user_lookup.find(input.user_id);
        let access_filter = crop_policy::record_access_filter(user);
        let crop_failure = MastersCropTaskScheduleBlueprintCreateFailure::new(
            MastersCropTaskScheduleBlueprintCreateFailureReason::CropNotFound,
        );

        let crop_entity = match self.crop_gateway.find_by_id(input.crop_id) {
            Ok(entity) => entity,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(crop_failure);
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        if crop_masters_crop_edit_access::assert_edit(&access_filter, &crop_entity).is_err() {
            self.output_port.on_failure(crop_failure);
            return Ok(());
        }

        let agricultural_task = match self.agricultural_task_gateway.find_by_id(task_id) {
            Ok(entity) => entity,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(MastersCropTaskScheduleBlueprintCreateFailure::new(
                    MastersCropTaskScheduleBlueprintCreateFailureReason::AgriculturalTaskNotFound,
                ));
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        let existing = self.blueprint_gateway.list_by_crop_id(input.crop_id)?;
        if masters_crop_task_schedule_blueprint_create_policy::duplicate(
            &existing,
            stage_order,
            task_id,
            gdd_trigger,
        ) {
            self.output_port.on_failure(MastersCropTaskScheduleBlueprintCreateFailure::new(
                MastersCropTaskScheduleBlueprintCreateFailureReason::Duplicate,
            ));
            return Ok(());
        }

        let persist_attrs = masters_crop_task_schedule_blueprint_create_policy::build_persist_attributes(
            &input,
            task_id,
            stage_order,
            gdd_trigger,
            &agricultural_task,
        );

        match self.blueprint_gateway.create(persist_attrs) {
            Ok(row) => {
                self.output_port.on_success(row);
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}

#[cfg(test)]
mod interactors_crop_masters_task_schedule_blueprint_create_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/crop/interactors_crop_masters_task_schedule_blueprint_create_interactor_test.rs"
    ));
}
