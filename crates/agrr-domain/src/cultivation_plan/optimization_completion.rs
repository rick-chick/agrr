//! Ruby: `Domain::CultivationPlan::OptimizationCompletion`

use std::collections::HashMap;

use crate::cultivation_plan::entities::CultivationPlanEntity;
use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::cultivation_plan::policies::cultivation_plan_optimization_complete_policy;

pub fn apply<G: CultivationPlanGateway + ?Sized>(
    gateway: &G,
    plan_id: i64,
) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
    let plan = gateway.find_by_id(plan_id)?;
    let field_cultivations = gateway.list_by_plan_id(plan_id)?;
    let statuses: Vec<String> = field_cultivations
        .iter()
        .filter_map(|fc| fc.status.clone())
        .collect();
    let plan_status = plan.status.as_deref().unwrap_or("");

    if !cultivation_plan_optimization_complete_policy::should_mark_plan_completed(
        plan_status,
        &statuses,
    ) {
        return Ok(plan);
    }

    let mut attrs = HashMap::new();
    attrs.insert("status".into(), "completed".into());
    gateway.update(plan_id, attrs)
}
