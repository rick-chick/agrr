//! Ruby: `Domain::CultivationPlan::Gateways::PlanSaveUserInteractionRuleGateway`

use crate::cultivation_plan::dtos::PlanSaveUserInteractionRuleSnapshot;
use crate::shared::attr::AttrMap;

pub trait PlanSaveUserInteractionRuleGateway: Send + Sync {
    fn find_by_user_id_and_source_interaction_rule_id(
        &self,
        user_id: i64,
        source_interaction_rule_id: i64,
    ) -> Result<Option<PlanSaveUserInteractionRuleSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn find_by_user_id_and_rule_type_and_source_group_and_target_group_and_region(
        &self,
        user_id: i64,
        rule_type: &str,
        source_group: &str,
        target_group: &str,
        region: Option<&str>,
    ) -> Result<Option<PlanSaveUserInteractionRuleSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn update(
        &self,
        user_id: i64,
        interaction_rule_id: i64,
        attributes: AttrMap,
    ) -> Result<PlanSaveUserInteractionRuleSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        user_id: i64,
        attributes: AttrMap,
    ) -> Result<PlanSaveUserInteractionRuleSnapshot, Box<dyn std::error::Error + Send + Sync>>;
}
