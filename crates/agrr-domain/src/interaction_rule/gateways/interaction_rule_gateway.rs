use crate::interaction_rule::entities::InteractionRuleEntity;
use crate::shared::attr::AttrMap;
use crate::shared::dtos::error::Error;
use crate::shared::user::User;
use crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter;

/// Ruby: gateway `soft_delete_with_undo` success branch
#[derive(Debug, Clone, PartialEq)]
pub struct SoftDeleteWithUndoSuccess {
    pub undo: serde_json::Value,
}

/// Ruby: `{ success:, undo_entity: }` / `{ error_dto: }`
#[derive(Debug, Clone, PartialEq)]
pub enum SoftDeleteWithUndoOutcome {
    Success(SoftDeleteWithUndoSuccess),
    Failure(Error),
}

/// Ruby: `Domain::InteractionRule::Gateways::InteractionRuleGateway`
pub trait InteractionRuleGateway: Send + Sync {
    fn find_by_id(&self, rule_id: i64) -> Result<InteractionRuleEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn list_index_for_filter(
        &self,
        filter: &ReferenceIndexListFilter,
    ) -> Result<Vec<InteractionRuleEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn create_for_user(
        &self,
        user: &User,
        attrs: AttrMap,
    ) -> Result<InteractionRuleEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn update_for_user(
        &self,
        user: &User,
        id: i64,
        attrs: AttrMap,
    ) -> Result<InteractionRuleEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn soft_delete_with_undo(
        &self,
        user: &User,
        rule_id: i64,
        auto_hide_after: i64,
        translator: &dyn crate::shared::ports::translator_port::TranslatorPort,
    ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>>;
}
