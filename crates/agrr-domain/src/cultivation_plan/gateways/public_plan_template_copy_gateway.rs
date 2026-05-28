//! Ruby: `Domain::CultivationPlan::Gateways::PublicPlanTemplateCopyGateway`

use serde_json::Value;

pub trait PublicPlanTemplateCopyGateway: Send + Sync {
    fn copy_cultivation_plan(
        &self,
        ctx: &Value,
        farm: &Value,
        crops: &[Value],
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>;

    fn establish_master_data_relationships(
        &self,
        ctx: &Value,
        farm: &Value,
        crops: &[Value],
        fields: &[Value],
        pests: &[Value],
        agricultural_tasks: &[Value],
        fertilizes: &[Value],
        pesticides: &[Value],
        interaction_rules: &[Value],
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn copy_plan_relations(
        &self,
        ctx: &Value,
        new_plan: &Value,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>;

    fn copy_task_schedules(
        &self,
        ctx: &Value,
        new_plan: &Value,
        field_cultivation_map: &Value,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
