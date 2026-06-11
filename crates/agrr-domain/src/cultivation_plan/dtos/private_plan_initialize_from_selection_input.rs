//! Ruby: `Domain::CultivationPlan::Dtos::PrivatePlanInitializeFromSelectionInput`

use crate::shared::user::User;

#[derive(Debug, Clone, PartialEq)]
pub struct PrivatePlanInitializeFromSelectionInput {
    pub farm_id: i64,
    pub user: User,
    pub plan_name: Option<String>,
}
