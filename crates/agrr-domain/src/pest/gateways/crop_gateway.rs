use crate::shared::record_ref::RecordRef;

/// Minimal crop surface for pest association (Ruby crop gateway subset).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CropRecord {
    pub id: i64,
    pub is_reference: bool,
    pub user_id: Option<i64>,
    pub region: Option<String>,
    pub name: Option<String>,
}

impl RecordRef for CropRecord {
    fn is_reference(&self) -> bool {
        self.is_reference
    }

    fn user_id(&self) -> Option<i64> {
        self.user_id
    }
}

/// Ruby: crop gateway methods used by pest interactors
pub trait CropGateway: Send + Sync {
    fn find_by_id(
        &self,
        crop_id: i64,
    ) -> Result<Option<CropRecord>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_by_name(
        &self,
        name: &str,
    ) -> Result<Vec<CropRecord>, Box<dyn std::error::Error + Send + Sync>>;
}
