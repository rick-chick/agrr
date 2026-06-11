//! Ruby: `Domain::CultivationPlan::Interactors::PrivatePlanInitializeFromSelectionInteractor`
//!
//! Private plan creation from farm selection only (empty plan + master field copy).

use time::{Date, Month};

use crate::cultivation_plan::dtos::{
    CultivationPlanInitFarm, PrivatePlanInitializeFromSelectionFailure,
    PrivatePlanInitializeFromSelectionInput, PrivatePlanInitializeFromSelectionOutput,
    PrivatePlanMasterFieldSeed,
};
use crate::cultivation_plan::policies::cultivation_plan_field_policy;
use crate::cultivation_plan::ports::{
    PrivatePlanExistingPlanGateway, PrivatePlanFarmResolveGateway, PrivatePlanInitializeCallablePort,
    PrivatePlanInitializeFromSelectionOutputPort, PrivatePlanOptimizationJobChainGateway,
    PrivatePlanSessionIdGeneratorPort,
};
use crate::field::gateways::FieldGateway;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::helpers::date_calendar::beginning_of_year;
use crate::shared::policies::farm_policy;
use crate::shared::ports::{ClockPort, LoggerPort, TranslatorPort};

pub struct PrivatePlanInitializeFromSelectionInteractor<'a, O, EP, F, FG, I, L, T, Ck, J> {
    output_port: &'a mut O,
    cultivation_plan_gateway: &'a EP,
    farm_gateway: &'a F,
    field_gateway: &'a FG,
    plan_initializer: &'a I,
    logger: &'a L,
    translator: &'a T,
    clock: &'a Ck,
    session_id_generator: &'a dyn PrivatePlanSessionIdGeneratorPort,
    job_chain_enqueuer: &'a J,
}

impl<'a, O, EP, F, FG, I, L, T, Ck, J>
    PrivatePlanInitializeFromSelectionInteractor<'a, O, EP, F, FG, I, L, T, Ck, J>
where
    O: PrivatePlanInitializeFromSelectionOutputPort,
    EP: PrivatePlanExistingPlanGateway,
    F: PrivatePlanFarmResolveGateway,
    FG: FieldGateway,
    I: PrivatePlanInitializeCallablePort,
    L: LoggerPort,
    T: TranslatorPort,
    Ck: ClockPort,
    J: PrivatePlanOptimizationJobChainGateway,
{
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        output_port: &'a mut O,
        cultivation_plan_gateway: &'a EP,
        farm_gateway: &'a F,
        field_gateway: &'a FG,
        plan_initializer: &'a I,
        logger: &'a L,
        translator: &'a T,
        clock: &'a Ck,
        session_id_generator: &'a dyn PrivatePlanSessionIdGeneratorPort,
        job_chain_enqueuer: &'a J,
    ) -> Self {
        Self {
            output_port,
            cultivation_plan_gateway,
            farm_gateway,
            field_gateway,
            plan_initializer,
            logger,
            translator,
            clock,
            session_id_generator,
            job_chain_enqueuer,
        }
    }

    pub fn call(
        &mut self,
        input: &PrivatePlanInitializeFromSelectionInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Err(err) = self.call_inner(input) {
            if err.downcast_ref::<RecordInvalidError>().is_some() {
                let invalid = err.downcast_ref::<RecordInvalidError>().unwrap();
                self.logger.error(&format!(
                    "❌ [PrivatePlanInitializeFromSelectionInteractor] RecordInvalid: {}",
                    invalid
                ));
                self.output_port.on_failure(PrivatePlanInitializeFromSelectionFailure::new(
                    PrivatePlanInitializeFromSelectionFailure::HTTP_UNPROCESSABLE_ENTITY,
                    invalid.to_string(),
                ));
                return Ok(());
            }
            return Err(err);
        }
        Ok(())
    }

    fn call_inner(
        &mut self,
        input: &PrivatePlanInitializeFromSelectionInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let farm = match self.resolve_owned_farm(input)? {
            Some(farm) => farm,
            None => {
                self.output_port.on_failure(PrivatePlanInitializeFromSelectionFailure::new(
                    PrivatePlanInitializeFromSelectionFailure::HTTP_NOT_FOUND,
                    self.translator.t("plans.errors.not_found", &Default::default()),
                ));
                return Ok(());
            }
        };

        if self
            .cultivation_plan_gateway
            .find_existing(farm.id, input.user.id)?
            .is_some()
        {
            self.output_port.on_failure(PrivatePlanInitializeFromSelectionFailure::new(
                PrivatePlanInitializeFromSelectionFailure::HTTP_UNPROCESSABLE_ENTITY,
                self.translator.t("plans.errors.plan_already_exists_annual", &Default::default()),
            ));
            return Ok(());
        }

        let master_fields = self.resolve_master_field_seeds(farm.id)?;
        if master_fields.is_empty() {
            self.output_port.on_failure(PrivatePlanInitializeFromSelectionFailure::new(
                PrivatePlanInitializeFromSelectionFailure::HTTP_UNPROCESSABLE_ENTITY,
                self.translator
                    .t("plans.errors.no_fields_in_farm", &Default::default()),
            ));
            return Ok(());
        }

        let plan_name = input
            .plan_name
            .as_deref()
            .filter(|n| !n.trim().is_empty())
            .unwrap_or(&farm.name)
            .to_string();
        let session_id = self.session_id_generator.generate();
        let today = self.clock.today();
        let planning_start_date = beginning_of_year(today);
        let planning_end_date = Date::from_calendar_date(today.year() + 1, Month::December, 31)
            .expect("valid end of year");

        let result = self.plan_initializer.call(
            &farm,
            &master_fields,
            input.user.id,
            &session_id,
            &plan_name,
            planning_start_date,
            planning_end_date,
        )?;

        let Some(plan) = result.cultivation_plan else {
            let msg = if result.errors.is_empty() {
                self.translator
                    .t("public_plans.save.error", &Default::default())
            } else {
                result.errors.join(", ")
            };
            self.logger.error(&format!(
                "❌ [PrivatePlanInitializeFromSelectionInteractor] Initialize failed: {msg}"
            ));
            self.output_port.on_failure(PrivatePlanInitializeFromSelectionFailure::new(
                PrivatePlanInitializeFromSelectionFailure::HTTP_UNPROCESSABLE_ENTITY,
                msg,
            ));
            return Ok(());
        };

        let plan_id = plan.id;
        self.logger.info(&format!(
            "✅ [PrivatePlanInitializeFromSelectionInteractor] CultivationPlan created: {plan_id}"
        ));

        self.job_chain_enqueuer.enqueue_after_create(plan_id)?;
        self.output_port
            .on_success(PrivatePlanInitializeFromSelectionOutput { id: plan_id });
        Ok(())
    }

    fn resolve_owned_farm(
        &self,
        input: &PrivatePlanInitializeFromSelectionInput,
    ) -> Result<Option<CultivationPlanInitFarm>, Box<dyn std::error::Error + Send + Sync>> {
        let farm = match self.farm_gateway.find_by_id(input.farm_id) {
            Ok(farm) => farm,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => return Ok(None),
            Err(err) => return Err(err),
        };

        if !farm_policy::owned_visible(&input.user, farm.is_reference, farm.user_id) {
            return Ok(None);
        }

        Ok(Some(CultivationPlanInitFarm {
            id: farm.id,
            name: farm.name,
        }))
    }

    fn resolve_master_field_seeds(
        &self,
        farm_id: i64,
    ) -> Result<Vec<PrivatePlanMasterFieldSeed>, Box<dyn std::error::Error + Send + Sync>> {
        let list = self.field_gateway.farm_fields_list(farm_id)?;
        let mut seeds: Vec<PrivatePlanMasterFieldSeed> = list
            .fields
            .iter()
            .filter_map(|field| {
                let area = field.area?;
                if cultivation_plan_field_policy::invalid_field_area(area) {
                    return None;
                }
                Some(PrivatePlanMasterFieldSeed {
                    name: field.display_name(),
                    area,
                    daily_fixed_cost: field.daily_fixed_cost,
                })
            })
            .collect();
        seeds.sort_by(|a, b| a.name.cmp(&b.name));
        Ok(seeds)
    }
}

#[cfg(test)]
mod interactors_private_plan_initialize_from_selection_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_private_plan_initialize_from_selection_interactor_test.rs"));
}
