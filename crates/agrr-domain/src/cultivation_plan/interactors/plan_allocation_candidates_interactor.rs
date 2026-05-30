//! Ruby: `Domain::CultivationPlan::Interactors::PlanAllocationCandidatesInteractor`

use serde_json::Value;
use time::Date;

use crate::crop::dtos::AddCropCropSnapshot;
use crate::cultivation_plan::dtos::CultivationPlanRestAuth;
use crate::cultivation_plan::gateways::PlanAllocationCandidatesGateway;

pub struct PlanAllocationCandidatesInteractor<'a, G> {
    plan_allocation_candidates_gateway: &'a G,
}

impl<'a, G> PlanAllocationCandidatesInteractor<'a, G>
where
    G: PlanAllocationCandidatesGateway,
{
    pub fn new(plan_allocation_candidates_gateway: &'a G) -> Self {
        Self {
            plan_allocation_candidates_gateway,
        }
    }

    #[allow(clippy::too_many_arguments)]
    pub fn call(
        &self,
        _auth: &CultivationPlanRestAuth,
        _plan_id: i64,
        _crop: &AddCropCropSnapshot,
        current_allocation: &Value,
        fields: &[Value],
        crops: &[Value],
        target_crop: &Value,
        weather_data: &Value,
        planning_start: Date,
        planning_end: Date,
        interaction_rules: Option<&Value>,
    ) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>> {
        let candidates = self.plan_allocation_candidates_gateway.candidates(
            current_allocation,
            fields,
            crops,
            target_crop,
            weather_data,
            planning_start,
            planning_end,
            interaction_rules,
        )?;
        Ok(candidates.into_iter().next())
    }
}
