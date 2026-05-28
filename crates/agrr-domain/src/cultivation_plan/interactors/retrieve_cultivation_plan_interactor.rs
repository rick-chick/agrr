//! Ruby: `Domain::CultivationPlan::Interactors::RetrieveCultivationPlanInteractor`

use crate::cultivation_plan::dtos::{CultivationPlanRestAuth, CultivationPlanWorkbenchSnapshot};
use crate::cultivation_plan::gateways::{
    CropRowsAvailableGateway, CultivationPlanGateway, CultivationPlanWorkbenchReadGateway,
};
use crate::cultivation_plan::interactors::rest_plan_access;
use crate::cultivation_plan::ports::RetrieveCultivationPlanOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::ports::LoggerPort;

pub struct RetrieveCultivationPlanInteractor<'a, O, PG, WG, AG, L> {
    output_port: &'a mut O,
    plan_gateway: &'a PG,
    workbench_read_gateway: &'a WG,
    available_crop_rows_gateway: &'a AG,
    logger: &'a L,
}

impl<'a, O, PG, WG, AG, L> RetrieveCultivationPlanInteractor<'a, O, PG, WG, AG, L>
where
    O: RetrieveCultivationPlanOutputPort,
    PG: CultivationPlanGateway,
    WG: CultivationPlanWorkbenchReadGateway,
    AG: CropRowsAvailableGateway,
    L: LoggerPort,
{
    pub fn new(
        output_port: &'a mut O,
        plan_gateway: &'a PG,
        workbench_read_gateway: &'a WG,
        available_crop_rows_gateway: &'a AG,
        logger: &'a L,
    ) -> Self {
        Self {
            output_port,
            plan_gateway,
            workbench_read_gateway,
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

        let mut base_snapshot = self
            .workbench_read_gateway
            .load_snapshot_by_plan_id(plan_id)?;

        let auth_value = serde_json::to_value(auth).unwrap_or(serde_json::Value::Null);
        let rows = self.available_crop_rows_gateway.list_by_farm_region(
            &auth_value,
            Some(&base_snapshot.farm_region),
        )?;
        base_snapshot.available_crop_rows = rows
            .into_iter()
            .map(|row| serde_json::to_value(row).unwrap_or(serde_json::Value::Null))
            .collect();

        let snapshot = CultivationPlanWorkbenchSnapshot {
            plan: base_snapshot.plan,
            fields: base_snapshot.fields,
            crops: base_snapshot.crops,
            cultivations: base_snapshot.cultivations,
            available_crop_rows: base_snapshot.available_crop_rows,
            farm_region: base_snapshot.farm_region,
        };

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
