//! Ruby: `Domain::Crop::Interactors::CropMastersTaskTemplateCreateInteractor`

use crate::agricultural_task::gateways::AgriculturalTaskGateway;
use crate::crop::dtos::{
    MastersCropTaskTemplateCreateFailure, MastersCropTaskTemplateCreateFailureReason,
    MastersCropTaskTemplateCreateInput,
};
use crate::crop::gateways::{CropGateway, CropMastersTaskTemplateGateway};
use crate::crop::policies::{
    crop_masters_crop_edit_access, masters_crop_task_template_create_policy,
};
use crate::crop::ports::CropMastersTaskTemplateCreateOutputPort;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;

pub struct CropMastersTaskTemplateCreateInteractor<'a, G, TG, O, U, AG> {
    output_port: &'a mut O,
    gateway: &'a G,
    crop_task_template_gateway: &'a TG,
    user_lookup: &'a U,
    agricultural_task_gateway: &'a AG,
}

impl<'a, G, TG, O, U, AG> CropMastersTaskTemplateCreateInteractor<'a, G, TG, O, U, AG>
where
    G: CropGateway,
    TG: CropMastersTaskTemplateGateway,
    O: CropMastersTaskTemplateCreateOutputPort,
    U: UserLookupGateway,
    AG: AgriculturalTaskGateway,
{
    pub fn new(
        output_port: &'a mut O,
        gateway: &'a G,
        crop_task_template_gateway: &'a TG,
        user_lookup: &'a U,
        agricultural_task_gateway: &'a AG,
    ) -> Self {
        Self {
            output_port,
            gateway,
            crop_task_template_gateway,
            user_lookup,
            agricultural_task_gateway,
        }
    }

    pub fn call(
        &mut self,
        input: MastersCropTaskTemplateCreateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let task_id = match input.agricultural_task_id {
            Some(id) if id > 0 => id,
            _ => {
                self.output_port.on_failure(MastersCropTaskTemplateCreateFailure::new(
                    MastersCropTaskTemplateCreateFailureReason::MissingAgriculturalTaskId,
                ));
                return Ok(());
            }
        };

        let user = self.user_lookup.find(input.user_id);
        let access_filter = crop_policy::record_access_filter(user);
        let crop_failure = MastersCropTaskTemplateCreateFailure::new(
            MastersCropTaskTemplateCreateFailureReason::CropNotFound,
        );

        let crop_entity = match self.gateway.find_by_id(input.crop_id) {
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

        let task_entity = match self.agricultural_task_gateway.find_by_id(task_id) {
            Ok(entity) => entity,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(MastersCropTaskTemplateCreateFailure::new(
                    MastersCropTaskTemplateCreateFailureReason::AgriculturalTaskNotFound,
                ));
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        if !access_filter.agricultural_task_template_associate_allows(
            task_entity.is_reference,
            task_entity.user_id,
        ) {
            self.output_port.on_failure(MastersCropTaskTemplateCreateFailure::new(
                MastersCropTaskTemplateCreateFailureReason::Forbidden,
            ));
            return Ok(());
        }

        let existing = self
            .crop_task_template_gateway
            .find_by_agricultural_task_id_and_crop_id(task_id, input.crop_id)?;
        if masters_crop_task_template_create_policy::duplicate(existing.as_ref()) {
            self.output_port.on_failure(MastersCropTaskTemplateCreateFailure::new(
                MastersCropTaskTemplateCreateFailureReason::Duplicate,
            ));
            return Ok(());
        }

        let persist_attrs =
            masters_crop_task_template_create_policy::build_persist_attributes(&input, &task_entity);

        match self.crop_task_template_gateway.create_detail(
            input.crop_id,
            task_id,
            persist_attrs,
        ) {
            Ok(template_entity) => {
                let masters_dto = masters_crop_task_template_create_policy::to_masters_dto(
                    &template_entity,
                    &task_entity,
                );
                self.output_port.on_success(masters_dto);
                Ok(())
            }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(record_invalid) => {
                    self.output_port.on_failure(
                        MastersCropTaskTemplateCreateFailure::validation_failed(
                            record_invalid.flatten_error_messages(),
                        ),
                    );
                    Ok(())
                }
                Err(err) => Err(err),
            },
        }
    }
}

#[cfg(test)]
mod interactors_crop_masters_task_template_create_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_masters_task_template_create_interactor_test.rs"));
}
