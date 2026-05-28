//! Ruby: `Domain::CultivationPlan::Interactors::AddFieldInteractor`

use crate::cultivation_plan::dtos::{CultivationPlanFieldSnapshot, CultivationPlanRestAuth};
use crate::cultivation_plan::gateways::{
    CultivationPlanFieldMutationGateway, CultivationPlanGateway,
    CultivationPlanOptimizationEventsGateway,
};
use crate::cultivation_plan::interactors::rest_plan_access;
use crate::cultivation_plan::policies::cultivation_plan_field_policy;
use crate::cultivation_plan::ports::AddFieldOutputPort;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::ports::LoggerPort;

pub struct AddFieldInteractor<'a, O, PG, FG, EG, L> {
    output: &'a mut O,
    plan_gateway: &'a PG,
    field_mutation_gateway: &'a FG,
    events_gateway: &'a EG,
    logger: &'a L,
}

impl<'a, O, PG, FG, EG, L> AddFieldInteractor<'a, O, PG, FG, EG, L>
where
    O: AddFieldOutputPort,
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
        field_name: &str,
        field_area: Option<f64>,
        daily_fixed_cost: Option<f64>,
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

        let field_area_f = field_area.unwrap_or(0.0);
        if cultivation_plan_field_policy::invalid_field_area(field_area_f) {
            self.output.on_invalid_field_params();
            return Ok(());
        }

        let existing_count = self.field_mutation_gateway.count_fields(plan.id)?;
        if cultivation_plan_field_policy::max_fields_reached(existing_count) {
            self.output.on_max_fields_limit();
            return Ok(());
        }

        let field_snapshot = self.field_mutation_gateway.create_field(
            plan.id,
            field_name,
            field_area_f,
            daily_fixed_cost,
        )?;
        let total_area = self.field_mutation_gateway.refresh_total_area(plan.id)?;

        let event_field = CultivationPlanFieldSnapshot {
            id: field_snapshot.id,
            name: field_snapshot.name.clone(),
            area: field_snapshot.area,
            cultivation_count: field_snapshot.cultivation_count,
        };
        self.events_gateway.broadcast_field_added(
            plan.id,
            &plan.plan_type,
            &event_field,
            total_area,
        )?;

        self.output.on_success(
            field_snapshot.id,
            &field_snapshot.name,
            field_snapshot.area,
            total_area,
        );
        Ok(())
    }

    pub fn call_catch_all(
        &mut self,
        auth: &CultivationPlanRestAuth,
        plan_id: i64,
        field_name: &str,
        field_area: Option<f64>,
        daily_fixed_cost: Option<f64>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.call(auth, plan_id, field_name, field_area, daily_fixed_cost) {
            Ok(()) => Ok(()),
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output.on_not_found();
                Ok(())
            }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(invalid) => {
                    let message = invalid
                        .detail_message()
                        .unwrap_or("invalid")
                        .to_string();
                    self.logger
                        .error(&format!("❌ [Add Field] Record invalid: {message}"));
                    self.output.on_record_invalid(&message);
                    Ok(())
                }
                Err(err) => {
                    self.logger.error(&format!("❌ [Add Field] Error: {err}"));
                    self.output.on_unexpected(&err.to_string());
                    Ok(())
                }
            },
        }
    }
}
