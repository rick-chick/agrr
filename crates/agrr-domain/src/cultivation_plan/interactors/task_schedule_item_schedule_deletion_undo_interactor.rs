//! Ruby: `Domain::CultivationPlan::Interactors::TaskScheduleItemScheduleDeletionUndoInteractor`

use crate::cultivation_plan::gateways::{CultivationPlanGateway, TaskScheduleItemMutationGateway};
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::ports::TaskScheduleItemMutationOutputPort;
use crate::deletion_undo::dtos::DeletionUndoScheduleInput;
use crate::cultivation_plan::ports::DeletionUndoSchedulePort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::ports::TranslatorPort;

pub struct TaskScheduleItemScheduleDeletionUndoInteractor<'a, O, P, G, D, T> {
    mutation_output_port: &'a mut O,
    plan_gateway: &'a P,
    mutation_gateway: &'a G,
    deletion_undo_interactor: &'a D,
    translator: &'a T,
}

impl<'a, O, P, G, D, T> TaskScheduleItemScheduleDeletionUndoInteractor<'a, O, P, G, D, T>
where
    O: TaskScheduleItemMutationOutputPort,
    P: CultivationPlanGateway,
    G: TaskScheduleItemMutationGateway,
    D: DeletionUndoSchedulePort,
    T: TranslatorPort,
{
    pub fn new(
        mutation_output_port: &'a mut O,
        plan_gateway: &'a P,
        mutation_gateway: &'a G,
        deletion_undo_interactor: &'a D,
        translator: &'a T,
    ) -> Self {
        Self {
            mutation_output_port,
            plan_gateway,
            mutation_gateway,
            deletion_undo_interactor,
            translator,
        }
    }

    pub fn call(
        &mut self,
        user_id: i64,
        plan_id: i64,
        item_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if !task_schedule_private_plan_access::access_allowed(self.plan_gateway, plan_id, user_id) {
            self.mutation_output_port.on_not_found();
            return Ok(());
        }

        let row = self
            .mutation_gateway
            .deletion_undo_schedule_row_for_item(plan_id, item_id)?;

        let mut opts = crate::shared::ports::TranslateOptions::default();
        opts.insert("name".into(), row.item_name.clone());
        let toast = self
            .translator
            .t("plans.task_schedule_items.undo.toast", &opts);

        let input = DeletionUndoScheduleInput::new(
            row.resource_type,
            Some(row.resource_id),
            Some(user_id),
            Some(toast),
        )
        .with_validate_before_schedule(true);
        self.deletion_undo_interactor.call(input)?;
        Ok(())
    }

    pub fn call_rescuing(
        &mut self,
        user_id: i64,
        plan_id: i64,
        item_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.call(user_id, plan_id, item_id) {
            Ok(()) => Ok(()),
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.mutation_output_port.on_not_found();
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}
