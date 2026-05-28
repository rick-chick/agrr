//! Public plan save output / persistence ports.

use crate::cultivation_plan::dtos::{
    PublicPlanSaveFailure, PublicPlanSaveFromSessionOutput, PublicPlanSaveWorkspace,
};

pub trait PublicPlanSaveFromSessionOutputPort {
    fn on_success(&mut self);
    fn on_failure(&mut self, failure: PublicPlanSaveFailure);
}

pub trait PublicPlanSavePersistencePort: Send + Sync {
    fn execute_save(
        &self,
        workspace: &PublicPlanSaveWorkspace,
    ) -> Result<PublicPlanSaveFromSessionOutput, Box<dyn std::error::Error + Send + Sync>>;
}
