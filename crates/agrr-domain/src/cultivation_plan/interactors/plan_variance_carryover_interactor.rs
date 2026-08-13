//! Copies variance learning summary from a source plan into a newly created plan snapshot.

use crate::cultivation_plan::gateways::{
    CultivationPlanGateway, CultivationPlanPrivateSnapshotReadGateway, PlanVarianceLearningGateway,
};
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::mappers::plan_vs_actual_mapper::{
    DEFAULT_TOP_VARIANCE_LIMIT, PlanVsActualMapper,
};
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::gateways::{UserLookupGateway, UserOrganizationScopeGateway};
use crate::shared::org_scope::member_organization_ids;
use crate::shared::ports::{LoggerPort, TranslatorPort};

pub struct PlanVarianceCarryoverInput {
    pub new_plan_id: i64,
    pub source_plan_id: i64,
    pub target_farm_id: i64,
    pub user_id: i64,
}

pub struct PlanVarianceCarryoverInteractor<'a, G, R, L, V, U, T, S> {
    cultivation_plan_gateway: &'a G,
    private_read_gateway: &'a R,
    variance_learning_gateway: &'a V,
    user_lookup: &'a U,
    scope_gateway: &'a S,
    translator: &'a T,
    logger: &'a L,
}

impl<'a, G, R, L, V, U, T, S> PlanVarianceCarryoverInteractor<'a, G, R, L, V, U, T, S>
where
    G: CultivationPlanGateway,
    R: CultivationPlanPrivateSnapshotReadGateway,
    V: PlanVarianceLearningGateway,
    U: UserLookupGateway,
    S: UserOrganizationScopeGateway,
    T: TranslatorPort,
    L: LoggerPort,
{
    pub fn new(
        cultivation_plan_gateway: &'a G,
        private_read_gateway: &'a R,
        variance_learning_gateway: &'a V,
        user_lookup: &'a U,
        scope_gateway: &'a S,
        translator: &'a T,
        logger: &'a L,
    ) -> Self {
        Self {
            cultivation_plan_gateway,
            private_read_gateway,
            variance_learning_gateway,
            user_lookup,
            scope_gateway,
            translator,
            logger,
        }
    }

    pub fn call(
        &self,
        input: PlanVarianceCarryoverInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if input.new_plan_id == input.source_plan_id {
            return Err(Box::new(RecordInvalidError::new(
                Some(
                    self.translator
                        .t("plans.errors.carryover_same_plan", &Default::default()),
                ),
                None,
            )));
        }

        let user = self.user_lookup.find(input.user_id);
        let org_ids = member_organization_ids(self.scope_gateway, user.id)?;

        let new_plan = self.cultivation_plan_gateway.find_by_id(input.new_plan_id)?;
        if new_plan.farm_id != input.target_farm_id {
            return Err(Box::new(RecordInvalidError::new(
                Some(
                    self.translator
                        .t("plans.errors.carryover_farm_mismatch", &Default::default()),
                ),
                None,
            )));
        }

        if !task_schedule_private_plan_access::access_allowed(
            self.cultivation_plan_gateway,
            input.source_plan_id,
            user.id,
            &org_ids,
        ) {
            return Err(Box::new(RecordInvalidError::new(
                Some(
                    self.translator
                        .t("plans.errors.carryover_source_not_found", &Default::default()),
                ),
                None,
            )));
        }

        let read_model = self
            .private_read_gateway
            .find_task_schedule_timeline_by_plan_id(input.source_plan_id)?;
        let mut summary = PlanVsActualMapper::summary_from_snapshot(&read_model, DEFAULT_TOP_VARIANCE_LIMIT);
        summary.plan_id = input.new_plan_id;

        self.variance_learning_gateway.save(
            input.new_plan_id,
            input.source_plan_id,
            &summary,
        )?;

        self.logger.info(&format!(
            "✅ [PlanVarianceCarryoverInteractor] Saved variance learning snapshot for plan {} from source {}",
            input.new_plan_id, input.source_plan_id
        ));
        Ok(())
    }
}

#[cfg(test)]
mod interactors_plan_variance_carryover_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/interactors_plan_variance_carryover_interactor_test.rs"
    ));
}
