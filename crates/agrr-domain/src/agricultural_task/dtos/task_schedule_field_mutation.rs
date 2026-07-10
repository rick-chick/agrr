use time::OffsetDateTime;

use super::TaskScheduleReplaceItem;

/// A single field/category schedule change to apply atomically for a plan.
#[derive(Debug, Clone)]
pub enum TaskScheduleFieldMutation {
    Replace {
        field_cultivation_id: i64,
        category: String,
        items: Vec<TaskScheduleReplaceItem>,
    },
    DeleteAll {
        field_cultivation_id: i64,
        category: String,
    },
}

/// All schedule writes for one generation run — applied in a single SQL transaction.
#[derive(Debug, Clone)]
pub struct TaskSchedulePlanMutations {
    pub cultivation_plan_id: i64,
    pub generated_at: OffsetDateTime,
    pub mutations: Vec<TaskScheduleFieldMutation>,
}
