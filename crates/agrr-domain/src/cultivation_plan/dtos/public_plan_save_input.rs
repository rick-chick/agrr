//! Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSaveInput`

use super::PublicPlanSaveSessionData;

#[derive(Debug, Clone)]
pub struct PublicPlanSaveInput {
    pub plan_id: Option<i64>,
    pub user_id: i64,
    pub session_data: Option<PublicPlanSaveSessionData>,
}

impl PublicPlanSaveInput {
    pub fn plan_id_present(&self) -> bool {
        self.plan_id.is_some_and(|id| id > 0)
    }
}
