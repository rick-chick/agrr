//! Ruby: `Domain::CultivationPlan::Interactors::RemoveFieldInteractor`

use crate::cultivation_plan::dtos::CultivationPlanRestAuth;
use crate::cultivation_plan::gateways::{
    CultivationPlanFieldMutationGateway, CultivationPlanGateway,
    CultivationPlanOptimizationEventsGateway,
};
use crate::cultivation_plan::interactors::rest_plan_access;
use crate::cultivation_plan::policies::cultivation_plan_field_policy;
use crate::cultivation_plan::ports::RemoveFieldOutputPort;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::ports::LoggerPort;

pub struct RemoveFieldInteractor<'a, O, PG, FG, EG, L> {
    output: &'a mut O,
    plan_gateway: &'a PG,
    field_mutation_gateway: &'a FG,
    events_gateway: &'a EG,
    logger: &'a L,
}

impl<'a, O, PG, FG, EG, L> RemoveFieldInteractor<'a, O, PG, FG, EG, L>
where
    O: RemoveFieldOutputPort,
    PG: CultivationPlanGateway,
    FG: CultivationPlanFieldMutationGateway,
    EG: CultivationPlanOptimizationEventsGateway,
    L: LoggerPort,
{
    pub fn new(
        output: &'a mut O,
        plan_gateway: &'a PG,
        field_mutation_gateway: &'a FG,
        events_gateway: &'a EG,
        logger: &'a L,
    ) -> Self {
        Self {
            output,
            plan_gateway,
            field_mutation_gateway,
            events_gateway,
            logger,
        }
    }

    pub fn call(
        &mut self,
        auth: &CultivationPlanRestAuth,
        plan_id: i64,
        field_id_param: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let plan = match self.plan_gateway.find_by_id(plan_id) {
            Ok(plan) => plan,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output.on_not_found();
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        if rest_plan_access::access_denied(&plan, auth) {
            self.output.on_not_found();
            return Ok(());
        }

        let field_id = field_id_param.parse::<i64>().unwrap_or(0);
        let field_row = self
            .field_mutation_gateway
            .find_field(plan.id, field_id)?;

        let Some(field_row) = field_row else {
            self.output.on_field_not_found();
            return Ok(());
        };

        if cultivation_plan_field_policy::cannot_remove_with_cultivations(field_row.cultivation_count)
        {
            self.output.on_cannot_remove_with_cultivations();
            return Ok(());
        }

        let existing_count = self.field_mutation_gateway.count_fields(plan.id)?;
        if cultivation_plan_field_policy::cannot_remove_last_field(existing_count) {
            self.output.on_cannot_remove_last_field();
            return Ok(());
        }

        self.field_mutation_gateway
            .delete_field(plan.id, field_id)?;
        let total_area = self.field_mutation_gateway.refresh_total_area(plan.id)?;

        self.events_gateway.broadcast_field_removed(
            plan.id,
            &plan.plan_type,
            field_id,
            total_area,
        )?;

        self.output.on_success(field_id, total_area);
        Ok(())
    }

    pub fn call_catch_all(
        &mut self,
        auth: &CultivationPlanRestAuth,
        plan_id: i64,
        field_id_param: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.call(auth, plan_id, field_id_param) {
            Ok(()) => Ok(()),
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output.on_not_found();
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                let invalid = err.downcast_ref::<RecordInvalidError>().unwrap();
                let message = invalid
                    .detail_message()
                    .unwrap_or("invalid")
                    .to_string();
                self.logger.error(&format!("❌ [Remove Field] Record invalid: {message}"));
                self.output.on_record_invalid(&message);
                Ok(())
            }
            Err(err) => {
                self.logger.error(&format!("❌ [Remove Field] Error: {err}"));
                self.output.on_unexpected(&err.to_string());
                Ok(())
            }
        }
    }
}
