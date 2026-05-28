use crate::pest::dtos::{PestDeleteUsage, PestShowDetail};
use crate::pest::entities::PestEntity;
use crate::shared::attr::AttrMap;
use crate::shared::dtos::Error;
use crate::shared::user::User;
use crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter;

/// Ruby: `Domain::Pest::Gateways::PestGateway`
pub trait PestGateway: Send + Sync {
    fn find_by_id(
        &self,
        pest_id: i64,
    ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn create_for_user(
        &self,
        user: &User,
        attrs: AttrMap,
    ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn update_for_user(
        &self,
        user: &User,
        id: i64,
        attrs: AttrMap,
    ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn list_index_for_filter(
        &self,
        filter: &ReferenceIndexListFilter,
    ) -> Result<Vec<PestEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn find_pest_show_detail(
        &self,
        id: i64,
    ) -> Result<PestShowDetail, Box<dyn std::error::Error + Send + Sync>>;

    fn find_delete_usage(
        &self,
        pest_id: i64,
    ) -> Result<PestDeleteUsage, Box<dyn std::error::Error + Send + Sync>>;

    fn soft_delete_with_undo(
        &self,
        user: &User,
        pest_id: i64,
        auto_hide_after: i64,
        translator: &dyn crate::shared::ports::TranslatorPort,
    ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>>;

    fn find_by_name(
        &self,
        user_id: i64,
        name: &str,
    ) -> Result<Option<PestEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_pests_for_crop_filtered(
        &self,
        crop_id: i64,
        pest_ids: &[i64],
        order: CropPestListOrder,
    ) -> Result<Vec<PestEntity>, Box<dyn std::error::Error + Send + Sync>>;
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CropPestListOrder {
    RecentFirst,
    IdAsc,
}

#[derive(Debug, Clone)]
pub enum SoftDeleteWithUndoOutcome {
    Success { undo: serde_json::Value },
    Failure(Error),
}
