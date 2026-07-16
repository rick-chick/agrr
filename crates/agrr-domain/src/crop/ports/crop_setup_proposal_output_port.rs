use crate::crop::dtos::{
    CropSetupProposalApplyResult, CropSetupProposalValidationError,
};
use serde_json::Value;

pub trait CropSetupProposalOutputPort {
    fn on_dry_run_success(&mut self, normalized: Value);
    fn on_validation_failure(&mut self, errors: Vec<CropSetupProposalValidationError>);
    fn on_apply_success(&mut self, result: CropSetupProposalApplyResult, normalized: Value);
    fn on_crop_not_found(&mut self);
}
