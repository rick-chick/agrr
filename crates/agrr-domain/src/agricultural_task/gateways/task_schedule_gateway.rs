use time::OffsetDateTime;

use crate::agricultural_task::dtos::{
    TaskSchedulePlanMutations, TaskScheduleReplaceItem,
};

/// Ruby: `Domain::AgriculturalTask::Gateways::TaskScheduleGateway`
pub trait TaskScheduleGateway: Send + Sync {
    fn delete_all_for_field_category(
        &self,
        cultivation_plan_id: i64,
        field_cultivation_id: i64,
        category: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn replace_schedule_for_field_category(
        &self,
        cultivation_plan_id: i64,
        field_cultivation_id: i64,
        category: &str,
        generated_at: OffsetDateTime,
        items: Vec<TaskScheduleReplaceItem>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    /// Apply all field/category mutations for one generation run in a single transaction.
    fn apply_plan_schedule_mutations(
        &self,
        plan_mutations: &TaskSchedulePlanMutations,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
