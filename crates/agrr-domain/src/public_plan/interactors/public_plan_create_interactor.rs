//! Ruby: `Domain::PublicPlan::Interactors::PublicPlanCreateInteractor`

use time::{Date, Month};

use crate::public_plan::catalog::FarmSizeCatalog;
use crate::public_plan::dtos::{
    PublicPlanCreateInput, PublicPlanCreateNoCropsViewContext, PublicPlanCreateOutput,
};
use crate::public_plan::gateways::{PublicPlanGateway, PublicPlanOptimizationJobChainGateway};
use crate::public_plan::ports::{
    PlanInitializerPort, PublicPlanCreateOutputPort, PublicPlanCropGateway,
};
use crate::shared::dtos::Error;
use crate::shared::ports::{ClockPort, LoggerPort};

const CALLER_LABEL: &str = "Domain::PublicPlan::Interactors::PublicPlanCreateInteractor";

/// Ruby: `ArgumentError` when clock does not respond to `today`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClockRequiredError;

/// Ruby: `Domain::PublicPlan::Interactors::PublicPlanCreateInteractor`
pub struct PublicPlanCreateInteractor<'a, G, CG, O, I, L> {
    output_port: &'a mut O,
    logger: &'a L,
    gateway: &'a G,
    crop_gateway: &'a CG,
    plan_initializer: &'a I,
    clock: &'a dyn ClockPort,
    optimization_job_chain_gateway: Option<&'a dyn PublicPlanOptimizationJobChainGateway>,
}

impl<'a, G, CG, O, I, L> PublicPlanCreateInteractor<'a, G, CG, O, I, L>
where
    G: PublicPlanGateway,
    CG: PublicPlanCropGateway,
    O: PublicPlanCreateOutputPort,
    I: PlanInitializerPort,
    L: LoggerPort,
{
    pub fn new(
        output_port: &'a mut O,
        gateway: &'a G,
        crop_gateway: &'a CG,
        plan_initializer: &'a I,
        logger: &'a L,
        clock: &'a dyn ClockPort,
        optimization_job_chain_gateway: Option<&'a dyn PublicPlanOptimizationJobChainGateway>,
    ) -> Self {
        Self {
            output_port,
            logger,
            gateway,
            crop_gateway,
            plan_initializer,
            clock,
            optimization_job_chain_gateway,
        }
    }

    /// Ruby: `#call(input_dto)`
    pub fn call(&mut self, input: PublicPlanCreateInput) {
        let farm = match self.gateway.find_by_farm_id(input.farm_id) {
            Some(f) => f,
            None => {
                self.output_port.on_failure(Error::new("Farm not found"));
                return;
            }
        };

        let farm_size = match self
            .gateway
            .find_by_farm_size_id(&input.farm_size_id)
            .or_else(|| {
                FarmSizeCatalog::find_by_id(&input.farm_size_id).map(Into::into)
            }) {
            Some(size) => size,
            None => {
                self.output_port.on_failure(Error::new("Invalid farm size"));
                return;
            }
        };

        if farm_size.area_sqm <= 0 {
            self.output_port.on_failure(Error::new("Invalid total area"));
            return;
        }

        let crops = self
            .gateway
            .list_by_ids(&input.crop_ids, &farm.region);
        if crops.is_empty() {
            let reference_crops = self.list_reference_crops_for_no_crops(&farm.region);
            self.output_port.on_no_crops_failure(PublicPlanCreateNoCropsViewContext {
                farm,
                farm_size,
                crops: reference_crops,
            });
            return;
        }

        let planning_start_date = self.clock.today();
        let planning_end_date =
            Date::from_calendar_date(planning_start_date.year(), Month::December, 31)
                .unwrap_or(planning_start_date);

        let result = self.plan_initializer.call(
            &farm,
            farm_size.area_sqm,
            &crops,
            input.user_id,
            &input.session_id,
            "public",
            planning_start_date,
            planning_end_date,
        );

        let Some(plan) = result.cultivation_plan else {
            let error_message = if result.errors.is_empty() {
                "Failed to create cultivation plan".to_string()
            } else {
                result.errors.join(", ")
            };
            self.output_port.on_failure(Error::new(error_message));
            return;
        };

        self.logger.info(&format!(
            "🌱 [PublicPlanCreateInteractor] Created new CultivationPlan with plan_id: {}",
            plan.id
        ));

        if let Some(job_chain) = self.optimization_job_chain_gateway {
            job_chain.enqueue_after_create(
                plan.id,
                CALLER_LABEL,
                input.redirect_path.as_deref(),
            );
        }

        self.output_port
            .on_success(PublicPlanCreateOutput::new(plan.id));
    }

    fn list_reference_crops_for_no_crops(&self, region: &str) -> Vec<crate::public_plan::dtos::PublicPlanCrop> {
        match self
            .crop_gateway
            .list_by_is_reference(true, Some(region))
        {
            Ok(crops) => crops,
            Err(err) => {
                self.logger.warn(&format!(
                    "❌ [PublicPlanCreateInteractor] list_reference_crops: {err}"
                ));
                vec![]
            }
        }
    }
}

#[cfg(test)]
mod interactors_public_plan_create_interactor_test_inline {
    use super::*;

    /// Validates clock at construction time (Ruby: `initialize`).
    fn validate_clock(clock: &dyn ClockPort) -> Result<(), ClockRequiredError> {
        let _ = clock.today();
        Ok(())
    }

    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/public_plan/interactors_public_plan_create_interactor_test.rs"));
}
