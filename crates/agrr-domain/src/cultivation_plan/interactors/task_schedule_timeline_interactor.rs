//! Ruby: `Domain::CultivationPlan::Interactors::TaskScheduleTimelineInteractor`

use crate::cultivation_plan::gateways::{CultivationPlanGateway, CultivationPlanPrivateReadGateway};
use crate::cultivation_plan::mappers::task_schedule_timeline_mapper::TaskScheduleTimelineMapper;
use crate::cultivation_plan::ports::TaskScheduleTimelineOutputPort;
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::ports::{ClockPort, LoggerPort, TranslatorPort};

pub struct TaskScheduleTimelineInteractor<'a, O, G, R, U, L, T, C> {
    output_port: &'a mut O,
    user_id: i64,
    plan_id: i64,
    private_read_gateway: &'a R,
    cultivation_plan_gateway: &'a G,
    translator: &'a T,
    logger: &'a L,
    user_lookup: &'a U,
    clock: &'a C,
}

impl<'a, O, G, R, U, L, T, C> TaskScheduleTimelineInteractor<'a, O, G, R, U, L, T, C>
where
    O: TaskScheduleTimelineOutputPort,
    G: CultivationPlanGateway,
    R: CultivationPlanPrivateReadGateway,
    U: UserLookupGateway,
    L: LoggerPort,
    T: TranslatorPort,
    C: ClockPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        plan_id: i64,
        private_read_gateway: &'a R,
        cultivation_plan_gateway: &'a G,
        translator: &'a T,
        logger: &'a L,
        user_lookup: &'a U,
        clock: &'a C,
    ) -> Self {
        Self {
            output_port,
            user_id,
            plan_id,
            private_read_gateway,
            cultivation_plan_gateway,
            translator,
            logger,
            user_lookup,
            clock,
        }
    }

    pub fn call(&mut self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);

        if !task_schedule_private_plan_access::access_allowed(
            self.cultivation_plan_gateway,
            self.plan_id,
            user.id,
        ) {
            return Err(Box::new(RecordNotFoundError));
        }

        match self
            .private_read_gateway
            .find_task_schedule_timeline_by_plan_id(self.plan_id)
        {
            Ok(read_model) => {
                let dto = TaskScheduleTimelineMapper::call(read_model, self.clock.today());
                self.output_port.on_success(dto);
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.logger.warn("[TaskScheduleTimelineInteractor] record_not_found");
                self.output_port
                    .on_failure(Error::new(self.translator.t("plans.errors.not_found", &Default::default())));
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                let invalid = err.downcast_ref::<RecordInvalidError>().unwrap();
                self.output_port.on_failure(Error::new(invalid.to_string()));
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}
