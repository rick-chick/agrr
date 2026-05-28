//! Ruby DTO stub for gateway/interactor porting

use serde_json::Value;

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleGenerationContext {
    pub plan_id: i64,
    pub payload: Value,
}
