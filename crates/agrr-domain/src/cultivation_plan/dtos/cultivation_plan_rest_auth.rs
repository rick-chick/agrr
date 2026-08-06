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
    pub member_organization_ids: Vec<i64>,
}

impl CultivationPlanRestAuth {
    pub fn private(user_id: i64) -> Self {
        Self {
            mode: CultivationPlanRestAuthMode::Private,
            user_id: Some(user_id),
            member_organization_ids: vec![],
        }
    }

    pub fn private_with_scope(user_id: i64, member_organization_ids: Vec<i64>) -> Self {
        Self {
            mode: CultivationPlanRestAuthMode::Private,
            user_id: Some(user_id),
            member_organization_ids,
        }
    }

    pub fn public() -> Self {
        Self {
            mode: CultivationPlanRestAuthMode::Public,
            user_id: None,
            member_organization_ids: vec![],
        }
    }

    pub fn is_private(&self) -> bool {
        matches!(self.mode, CultivationPlanRestAuthMode::Private)
    }
}
