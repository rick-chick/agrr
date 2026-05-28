//! Ruby DTO stub for gateway/interactor porting

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleItemDeletionUndoScheduleRow {
    pub resource_type: String,
    pub resource_id: i64,
    pub item_name: String,
}
