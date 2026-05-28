//! Ruby DTO stub for gateway/interactor porting

use serde_json::Value;

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanCropWithAgrr {
    pub crop_id: i64,
    pub agrr_requirement: Value,
}
