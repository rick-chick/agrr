//! Ruby: `Domain::CultivationPlan::Interactors::RetrieveCultivationPlanInteractor`

use crate::cultivation_plan::dtos::CultivationPlanRestAuth;
use crate::cultivation_plan::gateways::{
    CropRowsAvailableGateway, CultivationPlanGateway, CultivationPlanRestPlanReadGateway,
};
use crate::cultivation_plan::interactors::rest_plan_access;
use crate::cultivation_plan::mappers::{load_rest_plan_snapshot, workbench_from_snapshots};
use crate::cultivation_plan::ports::RetrieveCultivationPlanOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::ports::LoggerPort;

pub struct RetrieveCultivationPlanInteractor<'a, O, PG, RG, AG, L> {
    output_port: &'a mut O,
    plan_gateway: &'a PG,
    rest_plan_read_gateway: &'a RG,
    available_crop_rows_gateway: &'a AG,
    logger: &'a L,
}

impl<'a, O, PG, RG, AG, L> RetrieveCultivationPlanInteractor<'a, O, PG, RG, AG, L>
where
    O: RetrieveCultivationPlanOutputPort,
    PG: CultivationPlanGateway,
    RG: CultivationPlanRestPlanReadGateway,
    AG: CropRowsAvailableGateway,
    L: LoggerPort,
{
    pub fn new(
        output_port: &'a mut O,
        plan_gateway: &'a PG,
        rest_plan_read_gateway: &'a RG,
        available_crop_rows_gateway: &'a AG,
        logger: &'a L,
    ) -> Self {
        Self {
            output_port,
            plan_gateway,
            rest_plan_read_gateway,
            available_crop_rows_gateway,
            logger,
        }
    }

    pub fn call(
        &mut self,
        auth: &CultivationPlanRestAuth,
        plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let plan = match self.plan_gateway.find_by_id(plan_id) {
            Ok(plan) => plan,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_not_found();
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        if rest_plan_access::access_denied(&plan, auth) {
            self.output_port.on_not_found();
            return Ok(());
        }

        let rest_plan_snapshot = load_rest_plan_snapshot(self.rest_plan_read_gateway, plan_id)?;

        let auth_value = serde_json::to_value(auth).unwrap_or(serde_json::Value::Null);
        let available_crop_rows = self.available_crop_rows_gateway.list_by_farm_region(
            &auth_value,
            Some(&rest_plan_snapshot.farm_region),
        )?;

        let snapshot = workbench_from_snapshots(rest_plan_snapshot, available_crop_rows);

        self.output_port.on_success(snapshot);
        Ok(())
    }

    pub fn call_catch_all(
        &mut self,
        auth: &CultivationPlanRestAuth,
        plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.call(auth, plan_id) {
            Ok(()) => Ok(()),
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_not_found();
                Ok(())
            }
            Err(err) => {
                self.logger.error(&format!("❌ [Data] Error: {err}"));
                self.output_port.on_unexpected(&err.to_string());
                Ok(())
            }
        }
    }
}
