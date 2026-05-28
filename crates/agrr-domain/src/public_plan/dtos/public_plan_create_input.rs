//! Ruby: `Domain::PublicPlan::Dtos::PublicPlanCreateInput`

/// Ruby: `Domain::PublicPlan::Dtos::PublicPlanCreateInput`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PublicPlanCreateInput {
    pub farm_id: i64,
    pub farm_size_id: String,
    pub crop_ids: Vec<i64>,
    pub session_id: String,
    pub user_id: Option<i64>,
    pub redirect_path: Option<String>,
}

impl PublicPlanCreateInput {
    pub fn new(
        farm_id: i64,
        farm_size_id: impl Into<String>,
        crop_ids: Vec<i64>,
        session_id: impl Into<String>,
    ) -> Self {
        Self {
            farm_id,
            farm_size_id: farm_size_id.into(),
            crop_ids,
            session_id: session_id.into(),
            user_id: None,
            redirect_path: None,
        }
    }
}
