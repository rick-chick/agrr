//! Initialize interactor inputs / result.

use crate::cultivation_plan::entities::CultivationPlanEntity;

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanInitFarm {
    pub id: i64,
    pub name: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanInitCrop {
    pub id: i64,
    pub name: String,
    pub variety: Option<String>,
    pub area_per_unit: f64,
    pub revenue_per_area: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanInitializeResult {
    pub cultivation_plan: Option<CultivationPlanEntity>,
    pub errors: Vec<String>,
}

impl CultivationPlanInitializeResult {
    pub fn failure(message: impl Into<String>) -> Self {
        Self {
            cultivation_plan: None,
            errors: vec![message.into()],
        }
    }

    pub fn success(plan: CultivationPlanEntity) -> Self {
        Self {
            cultivation_plan: Some(plan),
            errors: vec![],
        }
    }

    pub fn is_success(&self) -> bool {
        self.errors.is_empty()
    }
}
