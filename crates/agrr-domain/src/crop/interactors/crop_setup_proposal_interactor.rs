//! Ruby: `Domain::Crop::Interactors::CropSetupProposalInteractor`

use crate::agricultural_task::gateways::AgriculturalTaskGateway;
use crate::crop::dtos::CropSetupProposalInput;
use crate::crop::gateways::{CropGateway, CropMastersTaskScheduleBlueprintGateway, CropSetupProposalGateway};
use crate::crop::policies::crop_masters_crop_edit_access;
use crate::crop::policies::crop_setup_proposal_policy;
use crate::crop::ports::CropSetupProposalOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;

pub struct CropSetupProposalInteractor<'a, CG, BG, AG, PG, O, U> {
    output_port: &'a mut O,
    crop_gateway: &'a CG,
    blueprint_gateway: &'a BG,
    agricultural_task_gateway: &'a AG,
    proposal_gateway: &'a PG,
    user_lookup: &'a U,
}

impl<'a, CG, BG, AG, PG, O, U> CropSetupProposalInteractor<'a, CG, BG, AG, PG, O, U>
where
    CG: CropGateway,
    BG: CropMastersTaskScheduleBlueprintGateway,
    AG: AgriculturalTaskGateway,
    PG: CropSetupProposalGateway,
    O: CropSetupProposalOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        crop_gateway: &'a CG,
        blueprint_gateway: &'a BG,
        agricultural_task_gateway: &'a AG,
        proposal_gateway: &'a PG,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            crop_gateway,
            blueprint_gateway,
            agricultural_task_gateway,
            proposal_gateway,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        input: CropSetupProposalInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(input.user_id);
        let access_filter = crop_policy::record_access_filter(user);

        let crop_entity = match self.crop_gateway.find_by_id(input.crop_id) {
            Ok(entity) => entity,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_crop_not_found();
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        if crop_masters_crop_edit_access::assert_edit(&access_filter, &crop_entity).is_err() {
            self.output_port.on_crop_not_found();
            return Ok(());
        }

        let existing_blueprints = self.blueprint_gateway.list_by_crop_id(input.crop_id)?;
        let existing_stages = self.crop_gateway.list_by_crop_id(input.crop_id)?;

        let (plan, normalized) = match crop_setup_proposal_policy::validate_and_normalize(
            &input.body,
            &existing_blueprints,
            &existing_stages,
        ) {
            Ok(value) => value,
            Err(errors) => {
                self.output_port.on_validation_failure(errors);
                return Ok(());
            }
        };

        match input.mode {
            crate::crop::dtos::CropSetupProposalMode::DryRun => {
                self.output_port.on_dry_run_success(normalized);
                Ok(())
            }
            crate::crop::dtos::CropSetupProposalMode::Apply => {
                let result = self.proposal_gateway.apply_plan(
                    input.user_id,
                    input.crop_id,
                    &plan,
                )?;
                self.output_port.on_apply_success(result, normalized);
                Ok(())
            }
        }
    }
}

#[cfg(test)]
mod interactors_crop_setup_proposal_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/crop/interactors_crop_setup_proposal_interactor_test.rs"
    ));
}
