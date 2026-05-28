//! Ruby: `Domain::CultivationPlan::Interactors::AddCropInteractor`

use std::collections::HashMap;

use serde_json::{json, Value};

use crate::cultivation_plan::dtos::{CultivationPlanRestAuth, PlanAllocationAdjustInput};
use crate::cultivation_plan::gateways::{CultivationPlanGateway, CultivationPlanPlanCropGateway};
use crate::cultivation_plan::interactors::rest_plan_access;
use crate::cultivation_plan::ports::{
    AddCropAdjustResultSink, AddCropCropResolveInputPort, AddCropOutputPort,
    PlanAllocationAdjustInputPort, PlanAllocationCandidatesPort,
};
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::ports::LoggerPort;
use crate::weather_data::WeatherPredictionError;

pub struct AddCropInteractor<'a, O, L, PA, CR, S, PG, PC, PAC> {
    output: &'a mut O,
    logger: &'a L,
    plan_allocation_adjust: &'a mut PA,
    add_crop_crop_resolve: &'a CR,
    add_crop_adjust_result_sink: &'a S,
    plan_gateway: &'a PG,
    plan_crop_gateway: &'a PC,
    plan_allocation_candidates: &'a PAC,
}

impl<'a, O, L, PA, CR, S, PG, PC, PAC> AddCropInteractor<'a, O, L, PA, CR, S, PG, PC, PAC>
where
    O: AddCropOutputPort,
    L: LoggerPort,
    PA: PlanAllocationAdjustInputPort,
    CR: AddCropCropResolveInputPort,
    S: AddCropAdjustResultSink,
    PG: CultivationPlanGateway,
    PC: CultivationPlanPlanCropGateway,
    PAC: PlanAllocationCandidatesPort,
{
    pub fn new(
        output: &'a mut O,
        logger: &'a L,
        plan_allocation_adjust: &'a mut PA,
        add_crop_crop_resolve: &'a CR,
        add_crop_adjust_result_sink: &'a S,
        plan_gateway: &'a PG,
        plan_crop_gateway: &'a PC,
        plan_allocation_candidates: &'a PAC,
    ) -> Self {
        Self {
            output,
            logger,
            plan_allocation_adjust,
            add_crop_crop_resolve,
            add_crop_adjust_result_sink,
            plan_gateway,
            plan_crop_gateway,
            plan_allocation_candidates,
        }
    }

    pub fn call(
        &mut self,
        auth: &CultivationPlanRestAuth,
        plan_id: i64,
        crop_id: &str,
        field_id: &str,
        display_range: &HashMap<String, Value>,
        ui_filter_context: &HashMap<String, Value>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let mut plan_crop_id: Option<i64> = None;
        let result = self.call_inner(
            auth,
            plan_id,
            crop_id,
            field_id,
            display_range,
            ui_filter_context,
            &mut plan_crop_id,
        );
        match result {
            Ok(()) => Ok(()),
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.rollback_plan_crop(plan_crop_id);
                self.output.on_not_found();
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                let invalid = err.downcast_ref::<RecordInvalidError>().unwrap();
                let message = invalid.detail_message().unwrap_or("invalid").to_string();
                self.logger.error(&format!("❌ [Add Crop] Record invalid: {message}"));
                self.rollback_plan_crop(plan_crop_id);
                self.output.on_record_invalid(&message);
                Ok(())
            }
            Err(err)
                if matches!(
                    err.downcast_ref::<WeatherPredictionError>(),
                    Some(WeatherPredictionError::WeatherDataNotFound(_))
                        | Some(WeatherPredictionError::InsufficientPredictionData(_))
                ) =>
            {
                self.logger
                    .warn(&format!("⚠️ [Add Crop] Prediction data incomplete: {err}"));
                self.rollback_plan_crop(plan_crop_id);
                self.output.on_prediction_incomplete(&err.to_string());
                Ok(())
            }
            Err(err) => {
                self.logger.error(&format!("❌ [Add Crop] Error: {err}"));
                self.rollback_plan_crop(plan_crop_id);
                self.output.on_unexpected(&err.to_string());
                Ok(())
            }
        }
    }

    fn call_inner(
        &mut self,
        auth: &CultivationPlanRestAuth,
        plan_id: i64,
        crop_id: &str,
        field_id: &str,
        display_range: &HashMap<String, Value>,
        ui_filter_context: &HashMap<String, Value>,
        plan_crop_id: &mut Option<i64>,
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

        let Some(crop_snapshot) = self.add_crop_crop_resolve.call(crop_id) else {
            self.output.on_crop_not_found();
            return Ok(());
        };

        let plan_crop_snapshot = self
            .plan_crop_gateway
            .create(plan_id, &crop_snapshot)?;
        *plan_crop_id = Some(plan_crop_snapshot.id);
        let plan_crop_display_name = plan_crop_snapshot.display_name.clone();

        let best = self.plan_allocation_candidates.call(
            auth,
            plan_id,
            &crop_snapshot,
            field_id,
            display_range,
            ui_filter_context,
        );

        let Some(best) = best else {
            self.rollback_plan_crop(*plan_crop_id);
            self.output.on_no_candidates();
            return Ok(());
        };

        let moves = vec![json!({
            "allocation_id": null,
            "action": "add",
            "crop_id": crop_snapshot.id.to_string(),
            "to_field_id": best.field_id,
            "to_start_date": best.start_date,
            "to_area": crop_snapshot.area_per_unit,
            "variety": crop_snapshot.variety,
        })];

        self.plan_allocation_adjust.call(PlanAllocationAdjustInput {
            plan_id,
            moves,
            auth: Some(auth.clone()),
        })?;

        let adjust_result = self.add_crop_adjust_result_sink.add_crop_adjust_result();
        if adjust_result.is_success() {
            self.output
                .on_success(plan_crop_snapshot.id, &plan_crop_display_name);
        } else {
            self.output.on_adjust_failed(&adjust_result);
        }
        Ok(())
    }

    fn rollback_plan_crop(&self, plan_crop_id: Option<i64>) {
        if let Some(id) = plan_crop_id {
            let _ = self.plan_crop_gateway.delete(id);
        }
    }
}
