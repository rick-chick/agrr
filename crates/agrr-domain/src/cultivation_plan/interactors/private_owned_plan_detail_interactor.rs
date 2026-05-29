//! Ruby: `Domain::CultivationPlan::Interactors::PrivateOwnedPlanDetailInteractor`

use crate::crop::gateways::CropGateway;
use crate::cultivation_plan::gateways::{
    CultivationPlanGateway, CultivationPlanPrivateSnapshotReadGateway,
};
use crate::cultivation_plan::mappers::private_plan_detail_to_detail;
use crate::cultivation_plan::policies::private_cultivation_plan_access_policy;
use crate::cultivation_plan::ports::PrivateOwnedPlanDetailOutputPort;
use crate::shared::dtos::Error;
use crate::shared::exceptions::{PersistenceFailedError, RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;
use crate::shared::ports::translator_port::TranslatorPort;
use crate::shared::ports::LoggerPort;

pub struct PrivateOwnedPlanDetailInteractor<'a, O, PR, CP, CG, U, T, L> {
    output_port: &'a mut O,
    user_id: i64,
    private_read_gateway: &'a PR,
    cultivation_plan_gateway: &'a CP,
    crop_gateway: &'a CG,
    _translator: &'a T,
    logger: &'a L,
    user_lookup: &'a U,
}

impl<'a, O, PR, CP, CG, U, T, L> PrivateOwnedPlanDetailInteractor<'a, O, PR, CP, CG, U, T, L>
where
    O: PrivateOwnedPlanDetailOutputPort,
    PR: CultivationPlanPrivateSnapshotReadGateway,
    CP: CultivationPlanGateway,
    CG: CropGateway,
    U: UserLookupGateway,
    T: TranslatorPort,
    L: LoggerPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        private_read_gateway: &'a PR,
        cultivation_plan_gateway: &'a CP,
        crop_gateway: &'a CG,
        _translator: &'a T,
        logger: &'a L,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            user_id,
            private_read_gateway,
            cultivation_plan_gateway,
            crop_gateway,
            _translator,
            logger,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let snapshot = self
            .private_read_gateway
            .find_plan_read_snapshot_by_plan_id(plan_id)?;
        let plan = self.cultivation_plan_gateway.find_by_id(plan_id)?;

        if private_cultivation_plan_access_policy::access_denied(&plan, user.id) {
            return Err(Box::new(RecordNotFoundError));
        }

        let filter = crop_policy::index_list_filter(&user);
        let mut palette_crop_entities = self.crop_gateway.list_index_for_filter(&filter)?;
        palette_crop_entities.sort_by(|a, b| a.name.cmp(&b.name));

        let detail = private_plan_detail_to_detail(&snapshot, &palette_crop_entities);
        self.output_port.on_success(detail);
        Ok(())
    }

    pub fn call_catch_all(
        &mut self,
        plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.call(plan_id) {
            Ok(()) => Ok(()),
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.logger.warn(&format!(
                    "[PrivateOwnedPlanDetailInteractor] RecordNotFound: {err}"
                ));
                self.output_port.on_not_found();
                Ok(())
            }
            Err(err) if err.downcast_ref::<PersistenceFailedError>().is_some() => {
                self.logger.error(&format!(
                    "[PrivateOwnedPlanDetailInteractor] PersistenceFailed: {err}"
                ));
                Err(err)
            }
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                let invalid = err.downcast_ref::<RecordInvalidError>().unwrap();
                self.logger.warn(&format!(
                    "[PrivateOwnedPlanDetailInteractor] RecordInvalid: {err}"
                ));
                let message = invalid
                    .detail_message()
                    .map(|s| s.to_string())
                    .unwrap_or_else(|| invalid.to_string());
                self.output_port.on_failure(Error::new(message));
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}
