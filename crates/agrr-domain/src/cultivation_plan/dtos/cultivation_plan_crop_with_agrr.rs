//! Ruby: `Domain::CultivationPlan::Dtos::CultivationPlanCropWithAgrr`

use serde_json::Value;

/// Ruby: `Domain::CultivationPlan::Dtos::CultivationPlanCropWithAgrr`
#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanCropWithAgrr {
    pub id: i64,
    pub name: String,
    pub crop_id: i64,
    pub agrr_requirement: Value,
    pub revenue_per_area: Option<f64>,
    pub crop_name: String,
}

impl CultivationPlanCropWithAgrr {
    pub fn new(
        id: i64,
        name: impl Into<String>,
        crop_id: i64,
        agrr_requirement: Value,
        revenue_per_area: Option<f64>,
        crop_name: impl Into<String>,
    ) -> Self {
        Self {
            id,
            name: name.into(),
            crop_id,
            agrr_requirement,
            revenue_per_area,
            crop_name: crop_name.into(),
        }
    }
}
