//! Ruby: `CultivationPlanInitializeInteractor::Result` (injected callable at edge).

use crate::public_plan::dtos::{PublicPlanCrop, PublicPlanFarm};

/// Created plan reference (id only at domain boundary).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CultivationPlanRef {
    pub id: i64,
}

/// Ruby: `CultivationPlanInitializeInteractor::Result`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlanInitializerResult {
    pub cultivation_plan: Option<CultivationPlanRef>,
    pub errors: Vec<String>,
}

impl PlanInitializerResult {
    pub fn success(plan_id: i64) -> Self {
        Self {
            cultivation_plan: Some(CultivationPlanRef { id: plan_id }),
            errors: vec![],
        }
    }

    pub fn failure(errors: Vec<String>) -> Self {
        Self {
            cultivation_plan: None,
            errors,
        }
    }

    pub fn success_flag(&self) -> bool {
        self.cultivation_plan.is_some() && self.errors.is_empty()
    }
}

/// Edge-injected plan initializer (Ruby: `@plan_initializer.call(...)`).
pub trait PlanInitializerPort: Send + Sync {
    fn call(
        &self,
        farm: &PublicPlanFarm,
        total_area: i64,
        crops: &[PublicPlanCrop],
        user_id: Option<i64>,
        session_id: &str,
        plan_type: &str,
        planning_start_date: time::Date,
        planning_end_date: time::Date,
    ) -> PlanInitializerResult;
}
