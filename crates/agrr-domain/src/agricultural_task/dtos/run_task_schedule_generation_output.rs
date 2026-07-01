//! Outcome of [`crate::agricultural_task::interactors::RunTaskScheduleGenerationInteractor`].

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RunTaskScheduleGenerationOutcome {
    Ready,
    Failed { i18n_key: String },
}
