use crate::crop::dtos::{
    CropSetupProposalApplyResult, CropSetupProposalPlan,
};
use std::error::Error;

pub trait CropSetupProposalGateway: Send + Sync {
    fn apply_plan(
        &self,
        user_id: i64,
        crop_id: i64,
        plan: &CropSetupProposalPlan,
    ) -> Result<CropSetupProposalApplyResult, Box<dyn Error + Send + Sync>>;
}
