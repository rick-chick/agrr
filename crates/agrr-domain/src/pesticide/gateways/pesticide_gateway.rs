use crate::pesticide::dtos::{
    PesticideApplicationDetailSnapshot, PesticideUsageConstraintSnapshot,
};
use crate::pesticide::entities::PesticideEntity;
use crate::shared::attr::AttrMap;
use crate::shared::dtos::Error;
use crate::shared::user::User;
use crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter;

/// Gateway DTO returned by `find_pesticide_show_detail` before interactor enrichment.
#[derive(Debug, Clone)]
pub struct PesticideShowDetailGatewayDto {
    pub pesticide: PesticideEntity,
    pub crop_name: Option<String>,
    pub pest_name: Option<String>,
    pub usage_constraint_snapshot: Option<PesticideUsageConstraintSnapshot>,
    pub application_detail_snapshot: Option<PesticideApplicationDetailSnapshot>,
}

/// Ruby: `Domain::Pesticide::Gateways::PesticideGateway`
pub trait PesticideGateway: Send + Sync {
    fn find_by_id(
        &self,
        pesticide_id: i64,
    ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn list_index_for_filter(
        &self,
        filter: &ReferenceIndexListFilter,
    ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn find_pesticide_show_detail(
        &self,
        id: i64,
    ) -> Result<PesticideShowDetailGatewayDto, Box<dyn std::error::Error + Send + Sync>>;

    fn create_for_user(
        &self,
        user: &User,
        attrs: AttrMap,
    ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn update_for_user(
        &self,
        user: &User,
        id: i64,
        attrs: AttrMap,
    ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn soft_delete_with_undo(
        &self,
        user: &User,
        pesticide_id: i64,
        auto_hide_after: i64,
        translator: &dyn crate::shared::ports::TranslatorPort,
    ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>>;

    fn list_by_crop_id_for_filter(
        &self,
        crop_id: i64,
        filter: &ReferenceIndexListFilter,
    ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>>;
}

#[derive(Debug, Clone)]
pub enum SoftDeleteWithUndoOutcome {
    Success { undo: serde_json::Value },
    Failure(Error),
}
