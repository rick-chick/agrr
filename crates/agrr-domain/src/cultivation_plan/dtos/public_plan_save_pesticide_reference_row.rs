//! Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSavePesticideReferenceRow`

use super::public_plan_save_pesticide_application_detail_row::PublicPlanSavePesticideApplicationDetailRow;
use super::public_plan_save_pesticide_usage_constraint_row::PublicPlanSavePesticideUsageConstraintRow;

/// Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSavePesticideReferenceRow`
#[derive(Debug, Clone)]
pub struct PublicPlanSavePesticideReferenceRow {
    pub reference_pesticide_id: i64,
    pub reference_crop_id: i64,
    pub reference_pest_id: i64,
    pub name: Option<String>,
    pub active_ingredient: Option<String>,
    pub description: Option<String>,
    pub region: Option<String>,
    pub usage_constraint: Option<PublicPlanSavePesticideUsageConstraintRow>,
    pub application_detail: Option<PublicPlanSavePesticideApplicationDetailRow>,
}

impl PublicPlanSavePesticideReferenceRow {
    pub fn new(
        reference_pesticide_id: i64,
        reference_crop_id: i64,
        reference_pest_id: i64,
        name: Option<String>,
        active_ingredient: Option<String>,
        description: Option<String>,
        region: Option<String>,
        usage_constraint: Option<PublicPlanSavePesticideUsageConstraintRow>,
        application_detail: Option<PublicPlanSavePesticideApplicationDetailRow>,
    ) -> Self {
        Self {
            reference_pesticide_id,
            reference_crop_id,
            reference_pest_id,
            name,
            active_ingredient,
            description,
            region,
            usage_constraint,
            application_detail,
        }
    }
}
