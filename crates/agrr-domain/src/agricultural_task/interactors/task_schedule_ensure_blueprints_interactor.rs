//! Blueprint ensure step before task schedule generation.
//!
//! Manual-first: does not auto-generate blueprints via AI. Empty blueprints are
//! handled by `TaskScheduleGenerateInteractor` (sync error → crop detail).

use crate::agricultural_task::ports::TaskScheduleBlueprintEnsureInputPort;

pub struct TaskScheduleEnsureBlueprintsInteractor;

impl TaskScheduleEnsureBlueprintsInteractor {
    pub fn new() -> Self {
        Self
    }

    pub fn ensure_for_plan(
        &self,
        _plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Ok(())
    }
}

impl TaskScheduleBlueprintEnsureInputPort for TaskScheduleEnsureBlueprintsInteractor {
    fn ensure_for_plan(
        &self,
        plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        TaskScheduleEnsureBlueprintsInteractor::ensure_for_plan(self, plan_id)
    }
}

impl Default for TaskScheduleEnsureBlueprintsInteractor {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod interactors_task_schedule_ensure_blueprints_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/agricultural_task/interactors_task_schedule_ensure_blueprints_interactor_test.rs"
    ));
}
