//! Ruby: `Domain::WorkRecord::Gateways::WorkRecordGateway`

use rust_decimal::Decimal;
use time::{Date, OffsetDateTime};

use crate::shared::dtos::Error;
use crate::work_record::dtos::{WorkRecordListInput, WorkRecordRead, WorkRecordUpdateInput};

/// Attributes persisted on create (built by interactor after prefill).
#[derive(Debug, Clone, PartialEq)]
pub struct WorkRecordCreatePersistAttrs {
    pub field_cultivation_id: Option<i64>,
    pub task_schedule_item_id: Option<i64>,
    pub agricultural_task_id: Option<i64>,
    pub name: String,
    pub task_type: Option<String>,
    pub actual_date: Date,
    pub amount: Option<Decimal>,
    pub amount_unit: Option<String>,
    pub time_spent_minutes: Option<i64>,
    pub notes: Option<String>,
    pub created_at: OffsetDateTime,
    pub updated_at: OffsetDateTime,
}

pub trait WorkRecordGateway: Send + Sync {
    fn create(
        &self,
        plan_id: i64,
        attrs: WorkRecordCreatePersistAttrs,
    ) -> Result<WorkRecordRead, Box<dyn std::error::Error + Send + Sync>>;

    fn list_for_plan(
        &self,
        plan_id: i64,
        filter: &WorkRecordListInput,
    ) -> Result<Vec<WorkRecordRead>, Box<dyn std::error::Error + Send + Sync>>;

    fn find_for_plan(
        &self,
        plan_id: i64,
        record_id: i64,
    ) -> Result<WorkRecordRead, Box<dyn std::error::Error + Send + Sync>>;

    fn update(
        &self,
        plan_id: i64,
        record_id: i64,
        input: &WorkRecordUpdateInput,
        updated_at: OffsetDateTime,
    ) -> Result<WorkRecordRead, Box<dyn std::error::Error + Send + Sync>>;

    fn destroy(
        &self,
        plan_id: i64,
        record_id: i64,
        actor_id: i64,
        toast_message: &str,
    ) -> Result<WorkRecordDestroyGatewayOutcome, Box<dyn std::error::Error + Send + Sync>>;
}

#[derive(Debug, Clone)]
pub enum WorkRecordDestroyGatewayOutcome {
    Success { undo: serde_json::Value },
    Failure(Error),
}
