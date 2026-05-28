use serde_json::Value;

/// Adapter-bound interaction rule source (Ruby: entity or AR record).
pub trait InteractionRuleAgrrFormatSource: Send + Sync {}

/// Ruby: `Domain::Shared::Ports::InteractionRuleAgrrFormatBuilderPort`
pub trait InteractionRuleAgrrFormatBuilderPort: Send + Sync {
    /// Ruby: `#build_from(entity_or_record)` — one agrr rule element (string keys).
    fn build_from(&self, entity_or_record: &dyn InteractionRuleAgrrFormatSource) -> Value;

    /// Ruby: `#build_array_from(entities_or_records)`
    fn build_array_from(
        &self,
        entities_or_records: &[&dyn InteractionRuleAgrrFormatSource],
    ) -> Vec<Value>;
}
