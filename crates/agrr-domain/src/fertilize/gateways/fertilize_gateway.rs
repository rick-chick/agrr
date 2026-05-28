use crate::fertilize::entities::FertilizeEntity;
use crate::shared::attr::AttrMap;
use crate::shared::dtos::Error;
use crate::shared::user::User;
use crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter;

/// Ruby: `Domain::Fertilize::Gateways::FertilizeGateway`
pub trait FertilizeGateway: Send + Sync {
    fn find_by_id(
        &self,
        fertilize_id: i64,
    ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn list_index_for_filter(
        &self,
        filter: &ReferenceIndexListFilter,
    ) -> Result<Vec<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn create_for_user(
        &self,
        user: &User,
        attrs: AttrMap,
    ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn update_for_user(
        &self,
        user: &User,
        id: i64,
        attrs: AttrMap,
    ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn soft_delete_with_undo(
        &self,
        user: &User,
        fertilize_id: i64,
        auto_hide_after: i64,
        translator: &dyn crate::shared::ports::TranslatorPort,
    ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>>;

    fn find_by_name(
        &self,
        user_id: i64,
        name: &str,
    ) -> Result<Option<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>>;
}

#[derive(Debug, Clone)]
pub enum SoftDeleteWithUndoOutcome {
    Success { undo: serde_json::Value },
    Failure(Error),
}
