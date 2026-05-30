//! Add crop orchestration ports.

use std::collections::HashMap;

use serde_json::Value;

use crate::crop::dtos::AddCropCropSnapshot;
use crate::cultivation_plan::dtos::{
    AddCropAdjustResult, CultivationPlanRestAuth, PlanAllocationAdjustInput,
};

pub trait AddCropOutputPort {
    fn on_success(&mut self, plan_crop_id: i64, plan_crop_display_name: &str);
    fn on_not_found(&mut self);
    fn on_crop_not_found(&mut self);
    fn on_prediction_incomplete(&mut self, technical_details: &str);
    fn on_no_candidates(&mut self);
    fn on_adjust_failed(&mut self, adjust_result: &AddCropAdjustResult);
    fn on_record_invalid(&mut self, message: &str);
    fn on_unexpected(&mut self, message: &str);
}

pub trait PlanAllocationAdjustInputPort: Send + Sync {
    fn call(
        &mut self,
        input: PlanAllocationAdjustInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}

pub trait AddCropCropResolveInputPort: Send + Sync {
    fn call(&self, crop_id: &str) -> Option<AddCropCropSnapshot>;
}

pub trait AddCropAdjustResultSink {
    fn add_crop_adjust_result(&self) -> AddCropAdjustResult;
}

pub trait PlanAllocationCandidatesPort: Send + Sync {
    fn call(
        &self,
        auth: &CultivationPlanRestAuth,
        plan_id: i64,
        crop: &AddCropCropSnapshot,
        field_id: &str,
        display_range: &HashMap<String, Value>,
        ui_filter_context: &HashMap<String, Value>,
    ) -> Result<
        Option<PlanAllocationCandidateBest>,
        Box<dyn std::error::Error + Send + Sync>,
    >;
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlanAllocationCandidateBest {
    pub field_id: String,
    pub start_date: String,
}
