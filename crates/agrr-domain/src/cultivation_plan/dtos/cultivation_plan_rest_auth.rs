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
    /// When set on public REST auth, mutation endpoints require a matching plan session.
    #[serde(default)]
    pub public_session_id: Option<String>,
}

impl CultivationPlanRestAuth {
    pub fn private(user_id: i64) -> Self {
        Self {
            mode: CultivationPlanRestAuthMode::Private,
            user_id: Some(user_id),
            member_organization_ids: vec![],
            public_session_id: None,
        }
    }

    pub fn private_with_scope(user_id: i64, member_organization_ids: Vec<i64>) -> Self {
        Self {
            mode: CultivationPlanRestAuthMode::Private,
            user_id: Some(user_id),
            member_organization_ids,
            public_session_id: None,
        }
    }

    pub fn public() -> Self {
        Self {
            mode: CultivationPlanRestAuthMode::Public,
            user_id: None,
            member_organization_ids: vec![],
            public_session_id: None,
        }
    }

    pub fn public_mutation(session_id: impl Into<String>) -> Self {
        Self {
            mode: CultivationPlanRestAuthMode::Public,
            user_id: None,
            member_organization_ids: vec![],
            public_session_id: Some(session_id.into()),
        }
    }

    pub fn is_private(&self) -> bool {
        matches!(self.mode, CultivationPlanRestAuthMode::Private)
    }
}
