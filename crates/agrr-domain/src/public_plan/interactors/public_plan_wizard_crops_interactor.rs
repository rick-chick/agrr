//! Ruby: `Domain::PublicPlan::Interactors::PublicPlanWizardCropsInteractor`

use crate::crop::gateways::CropGateway;
use crate::farm::gateways::FarmGateway;
use crate::public_plan::ports::PublicPlanWizardCropsOutputPort;
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::ports::LoggerPort;

/// Ruby: `Domain::PublicPlan::Interactors::PublicPlanWizardCropsInteractor`
pub struct PublicPlanWizardCropsInteractor<'a, FG, CG, O, L> {
    output_port: &'a mut O,
    farm_gateway: &'a FG,
    crop_gateway: &'a CG,
    logger: &'a L,
}

impl<'a, FG, CG, O, L> PublicPlanWizardCropsInteractor<'a, FG, CG, O, L>
where
    FG: FarmGateway,
    CG: CropGateway,
    O: PublicPlanWizardCropsOutputPort,
    L: LoggerPort,
{
    pub fn new(
        output_port: &'a mut O,
        farm_gateway: &'a FG,
        crop_gateway: &'a CG,
        logger: &'a L,
    ) -> Self {
        Self {
            output_port,
            farm_gateway,
            crop_gateway,
            logger,
        }
    }

    pub fn call(
        &mut self,
        farm_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let region = match self.farm_gateway.find_by_id(farm_id) {
            Ok(farm) => farm.region,
            Err(_) => {
                self.output_port.on_farm_not_found();
                return Ok(());
            }
        };
        let Some(region) = region.filter(|r| !r.trim().is_empty()) else {
            self.output_port.on_farm_not_found();
            return Ok(());
        };

        match self
            .crop_gateway
            .list_by_is_reference(true, Some(region.as_str()))
        {
            Ok(crops) => {
                self.output_port.on_success(crops);
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                let message = err.to_string();
                self.output_port.on_failure(Error::new(message));
                Ok(())
            }
            Err(err) => {
                self.logger.error(&format!(
                    "[PublicPlanWizardCropsInteractor] unexpected: {err}"
                ));
                Err(err)
            }
        }
    }
}
