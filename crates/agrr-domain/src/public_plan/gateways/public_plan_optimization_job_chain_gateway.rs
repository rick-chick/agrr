//! Ruby: `Domain::PublicPlan::Gateways::PublicPlanOptimizationJobChainGateway`

/// Ruby: `Domain::PublicPlan::Gateways::PublicPlanOptimizationJobChainGateway`
pub trait PublicPlanOptimizationJobChainGateway: Send + Sync {
    fn enqueue_after_create(
        &self,
        cultivation_plan_id: i64,
        caller_label: &str,
        redirect_path: Option<&str>,
    );
}
