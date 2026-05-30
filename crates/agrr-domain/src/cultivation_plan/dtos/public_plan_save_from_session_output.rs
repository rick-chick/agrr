//! Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSaveFromSessionOutput`

use super::PublicPlanSaveSkippedItems;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PublicPlanSaveFromSessionOutput {
    pub success: bool,
    pub error_message: Option<String>,
    pub new_cultivation_plan_id: Option<i64>,
    pub skipped_items: Option<PublicPlanSaveSkippedItems>,
}

impl PublicPlanSaveFromSessionOutput {
    pub fn success_with(
        new_cultivation_plan_id: Option<i64>,
        skipped_items: PublicPlanSaveSkippedItems,
    ) -> Self {
        Self {
            success: true,
            error_message: None,
            new_cultivation_plan_id,
            skipped_items: Some(skipped_items),
        }
    }

    pub fn failure(message: impl Into<String>) -> Self {
        Self {
            success: false,
            error_message: Some(message.into()),
            new_cultivation_plan_id: None,
            skipped_items: None,
        }
    }
}
