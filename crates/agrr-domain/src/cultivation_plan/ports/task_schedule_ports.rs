//! Task schedule mutation / timeline output ports.

use crate::cultivation_plan::dtos::TaskScheduleTimeline;
use crate::shared::dtos::Error;
use std::collections::BTreeMap;

use serde_json::Value;

pub trait TaskScheduleTimelineOutputPort {
    fn on_success(&mut self, dto: TaskScheduleTimeline);
    fn on_failure(&mut self, error: Error);
}

pub trait TaskScheduleItemMutationOutputPort {
    fn on_created(&mut self, item_payload: Value);
    fn on_success(&mut self, item_payload: Value);
    fn on_record_invalid(&mut self, errors: BTreeMap<String, Vec<String>>, fallback_message: &str);
    fn on_not_found(&mut self);
}

pub trait RegenerateTaskScheduleOutputPort {
    fn on_success(&mut self);
    fn on_not_found(&mut self);
}

pub trait PrivatePlanInitializeFromSelectionOutputPort {
    fn on_success(
        &mut self,
        dto: crate::cultivation_plan::dtos::PrivatePlanInitializeFromSelectionOutput,
    );
    fn on_failure(
        &mut self,
        failure: crate::cultivation_plan::dtos::PrivatePlanInitializeFromSelectionFailure,
    );
}

pub trait UserAgriculturalTaskMappingPort: Send + Sync {
    fn user_task_id_for(&self, reference_task_id: Option<i64>) -> Option<i64>;
}
