//! Ruby: `Domain::CultivationPlan::Interactors::PlanVsActualSummaryInteractor`

use crate::cultivation_plan::gateways::{
    CultivationPlanGateway, CultivationPlanPrivateSnapshotReadGateway,
};
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::mappers::plan_vs_actual_mapper::{
    DEFAULT_TOP_VARIANCE_LIMIT, PlanVsActualMapper,
};
use crate::cultivation_plan::ports::PlanVsActualSummaryOutputPort;
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::{UserLookupGateway, UserOrganizationScopeGateway};
use crate::shared::org_scope::member_organization_ids;
use crate::shared::ports::{LoggerPort, TranslatorPort};

pub struct PlanVsActualSummaryInteractor<'a, O, G, R, U, L, T, S> {
    output_port: &'a mut O,
    user_id: i64,
    plan_id: i64,
    top_n: usize,
    private_read_gateway: &'a R,
    cultivation_plan_gateway: &'a G,
    translator: &'a T,
    logger: &'a L,
    user_lookup: &'a U,
    scope_gateway: &'a S,
}

impl<'a, O, G, R, U, L, T, S> PlanVsActualSummaryInteractor<'a, O, G, R, U, L, T, S>
where
    O: PlanVsActualSummaryOutputPort,
    G: CultivationPlanGateway,
    R: CultivationPlanPrivateSnapshotReadGateway,
    U: UserLookupGateway,
    L: LoggerPort,
    T: TranslatorPort,
    S: UserOrganizationScopeGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        plan_id: i64,
        top_n: usize,
        private_read_gateway: &'a R,
        cultivation_plan_gateway: &'a G,
        translator: &'a T,
        logger: &'a L,
        user_lookup: &'a U,
        scope_gateway: &'a S,
    ) -> Self {
        Self {
            output_port,
            user_id,
            plan_id,
            top_n,
            private_read_gateway,
            cultivation_plan_gateway,
            translator,
            logger,
            user_lookup,
            scope_gateway,
        }
    }

    pub fn call(&mut self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let org_ids = member_organization_ids(self.scope_gateway, user.id)?;

        if !task_schedule_private_plan_access::access_allowed(
            self.cultivation_plan_gateway,
            self.plan_id,
            user.id,
            &org_ids,
        ) {
            return Err(Box::new(RecordNotFoundError));
        }

        match self
            .private_read_gateway
            .find_task_schedule_timeline_by_plan_id(self.plan_id)
        {
            Ok(read_model) => {
                let top_n = if self.top_n == 0 {
                    DEFAULT_TOP_VARIANCE_LIMIT
                } else {
                    self.top_n
                };
                let dto = PlanVsActualMapper::summary_from_snapshot(&read_model, top_n);
                self.output_port.on_success(dto);
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.logger.warn("[PlanVsActualSummaryInteractor] record_not_found");
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
