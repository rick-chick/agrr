//! Ruby: `InteractionRuleGateway#list_by_cultivation_plan_id` (optimize path only).

use crate::interaction_rule::entities::InteractionRuleEntity;

/// Rules for a cultivation plan's farm region (reference + user-owned).
pub trait InteractionRulePlanReadGateway: Send + Sync {
    fn list_by_cultivation_plan_id(
        &self,
        cultivation_plan_id: i64,
    ) -> Result<Vec<InteractionRuleEntity>, Box<dyn std::error::Error + Send + Sync>>;
}
