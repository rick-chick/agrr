//! Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSaveWorkspace`

use super::PublicPlanSaveSessionData;

#[derive(Debug, Clone)]
pub struct PublicPlanSaveWorkspace {
    pub user_id: i64,
    pub session_data: PublicPlanSaveSessionData,
}
