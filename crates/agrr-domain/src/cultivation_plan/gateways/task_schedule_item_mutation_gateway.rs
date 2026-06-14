//! Ruby: `Domain::CultivationPlan::Gateways::TaskScheduleItemMutationGateway`

use crate::cultivation_plan::dtos::{
    TaskScheduleCropTaskTemplateSnapshot, TaskScheduleFieldCultivationSnapshot,
    TaskScheduleItemAmountSnapshot, TaskScheduleItemDeletionUndoScheduleRow,
};
use crate::shared::attr::AttrMap;
use serde_json::Value;
use time::OffsetDateTime;

pub trait TaskScheduleItemMutationGateway: Send + Sync {
    fn find_field_cultivation_for_create(
        &self,
        plan_id: i64,
        field_cultivation_id: i64,
    ) -> Result<TaskScheduleFieldCultivationSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn find_crop_task_template_for_mutation(
        &self,
        template_id: Option<i64>,
    ) -> Result<Option<TaskScheduleCropTaskTemplateSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn find_item_amount_snapshot(
        &self,
        plan_id: i64,
        item_id: i64,
    ) -> Result<TaskScheduleItemAmountSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        plan_id: i64,
        attributes: AttrMap,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>;

    fn update_item_for_plan(
        &self,
        plan_id: i64,
        item_id: i64,
        attributes: AttrMap,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>;

    fn skip_item_for_plan(
        &self,
        plan_id: i64,
        item_id: i64,
        cancelled_at: OffsetDateTime,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>;

    fn unskip_item_for_plan(
        &self,
        plan_id: i64,
        item_id: i64,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>;

    fn deletion_undo_schedule_row_for_item(
        &self,
        plan_id: i64,
        item_id: i64,
    ) -> Result<TaskScheduleItemDeletionUndoScheduleRow, Box<dyn std::error::Error + Send + Sync>>;
}
