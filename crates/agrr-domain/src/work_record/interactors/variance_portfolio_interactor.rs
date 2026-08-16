//! Aggregates plan-vs-actual variance stats across all private plans for work hub.

use crate::cultivation_plan::gateways::{
    CultivationPlanGateway, CultivationPlanPrivateReadGateway,
    CultivationPlanPrivateSnapshotReadGateway, PlanVarianceLearningGateway,
    WeatherRescheduleProposalReadGateway,
};
use crate::cultivation_plan::mappers::weather_reschedule_proposal_mapper::WeatherRescheduleProposalMapper;
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::mappers::plan_vs_actual_mapper::PlanVsActualMapper;
use crate::cultivation_plan::policies::plan_variance_summary_stats_policy::{
    stats_from_summary, EMPTY_PLAN_VARIANCE_SUMMARY_STATS,
};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{PersistenceFailedError, RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::{UserLookupGateway, UserOrganizationScopeGateway};
use crate::shared::org_scope::member_organization_ids;
use crate::shared::ports::{LoggerPort, TranslatorPort};
use crate::work_record::dtos::VariancePortfolioRow;
use crate::work_record::policies::variance_portfolio_carryover_policy::carryover_not_imported;
use crate::work_record::ports::VariancePortfolioOutputPort;

pub struct VariancePortfolioInteractor<'a, O, CP, PR, PS, V, W, U, L, T, S> {
    output_port: &'a mut O,
    user_id: i64,
    private_read_gateway: &'a PR,
    private_snapshot_gateway: &'a PS,
    variance_learning_gateway: &'a V,
    weather_read_gateway: &'a W,
    cultivation_plan_gateway: &'a CP,
    translator: &'a T,
    logger: &'a L,
    user_lookup: &'a U,
    scope_gateway: &'a S,
}

impl<'a, O, CP, PR, PS, V, W, U, L, T, S>
    VariancePortfolioInteractor<'a, O, CP, PR, PS, V, W, U, L, T, S>
where
    O: VariancePortfolioOutputPort,
    CP: CultivationPlanGateway,
    PR: CultivationPlanPrivateReadGateway,
    PS: CultivationPlanPrivateSnapshotReadGateway,
    V: PlanVarianceLearningGateway,
    W: WeatherRescheduleProposalReadGateway,
    U: UserLookupGateway,
    L: LoggerPort,
    T: TranslatorPort,
    S: UserOrganizationScopeGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        private_read_gateway: &'a PR,
        private_snapshot_gateway: &'a PS,
        variance_learning_gateway: &'a V,
        cultivation_plan_gateway: &'a CP,
        translator: &'a T,
        logger: &'a L,
        user_lookup: &'a U,
        scope_gateway: &'a S,
        weather_read_gateway: &'a W,
    ) -> Self {
        Self {
            output_port,
            user_id,
            private_read_gateway,
            private_snapshot_gateway,
            variance_learning_gateway,
            weather_read_gateway,
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

        let plans = match self
            .private_read_gateway
            .list_private_plan_index_rows_by_user_id(user.id)
        {
            Ok(rows) => rows,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.logger.warn("[VariancePortfolioInteractor] record_not_found");
                let message = self.translator.t("plans.errors.session_invalid", &Default::default());
                self.output_port.on_failure(Error::new(message));
                return Ok(());
            }
            Err(err) if err.downcast_ref::<PersistenceFailedError>().is_some() => {
                self.logger.error(&format!("[VariancePortfolioInteractor] PersistenceFailed: {err}"));
                return Err(err);
            }
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                let invalid = err.downcast_ref::<RecordInvalidError>().unwrap();
                self.logger.warn(&format!("[VariancePortfolioInteractor] RecordInvalid: {err}"));
                let message = invalid
                    .detail_message()
                    .map(|s| s.to_string())
                    .unwrap_or_else(|| invalid.to_string());
                self.output_port.on_failure(Error::new(message));
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        let mut rows = Vec::with_capacity(plans.len());
        for plan in &plans {
            if !task_schedule_private_plan_access::access_allowed(
                self.cultivation_plan_gateway,
                plan.id,
                user.id,
                &org_ids,
            ) {
                continue;
            }

            let stats = match self
                .private_snapshot_gateway
                .find_task_schedule_timeline_by_plan_id(plan.id)
            {
                Ok(read_model) => {
                    let summary = PlanVsActualMapper::summary_from_snapshot(&read_model, 0);
                    stats_from_summary(&summary)
                }
                Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                    EMPTY_PLAN_VARIANCE_SUMMARY_STATS
                }
                Err(err) => return Err(err),
            };

            let has_learning_snapshot = self
                .variance_learning_gateway
                .find_by_plan_id(plan.id)?
                .is_some();

            let weather_trigger_count = match self
                .weather_read_gateway
                .find_context_by_plan_id(plan.id)
            {
                Ok(context) => {
                    WeatherRescheduleProposalMapper::proposals_from_context(&context).len() as i64
                }
                Err(_) => 0,
            };

            rows.push(VariancePortfolioRow {
                farm_id: plan.farm_id,
                farm_name: plan.farm_display_name.clone(),
                plan_id: plan.id,
                plan_year: plan.plan_year,
                status: plan.status.clone(),
                unrecorded_count: stats.unrecorded_count,
                gdd_delay_count: stats.gdd_delay_count,
                threshold_exceeded_count: stats.threshold_exceeded_count,
                days_threshold_exceeded_count: stats.days_threshold_exceeded_count,
                carryover_not_imported: carryover_not_imported(plan, &plans, has_learning_snapshot),
                weather_trigger_count,
            });
        }

        self.output_port.on_success(rows);
        Ok(())
    }
}

#[cfg(test)]
mod interactors_variance_portfolio_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/work_record/interactors_variance_portfolio_interactor_test.rs"
    ));
}
