//! Ruby: `Domain::CultivationPlan::Dtos::CultivationPlanRestAuth`

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum CultivationPlanRestAuthMode {
    Private,
    Public,
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct CultivationPlanRestAuth {
    pub mode: CultivationPlanRestAuthMode,
    pub user_id: Option<i64>,
}

impl CultivationPlanRestAuth {
    pub fn private(user_id: i64) -> Self {
        Self {
            mode: CultivationPlanRestAuthMode::Private,
            user_id: Some(user_id),
        }
    }

    pub fn public() -> Self {
        Self {
            mode: CultivationPlanRestAuthMode::Public,
            user_id: None,
        }
    }

    pub fn is_private(&self) -> bool {
        matches!(self.mode, CultivationPlanRestAuthMode::Private)
    }
}
