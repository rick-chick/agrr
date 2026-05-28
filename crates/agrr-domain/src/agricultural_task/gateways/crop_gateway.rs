use crate::shared::record_ref::RecordRef;

/// Minimal crop surface for task template sync (Ruby crop gateway list methods).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CropRecord {
    pub id: i64,
    pub is_reference: bool,
    pub user_id: Option<i64>,
}

impl RecordRef for CropRecord {
    fn is_reference(&self) -> bool {
        self.is_reference
    }

    fn user_id(&self) -> Option<i64> {
        self.user_id
    }
}

/// Ruby: crop gateway methods used by `AgriculturalTaskUpdateInteractor`
pub trait CropGateway: Send + Sync {
    fn list_by_is_reference(
        &self,
        is_reference: bool,
        region: Option<&str>,
    ) -> Result<Vec<CropRecord>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_by_user_id(
        &self,
        user_id: i64,
        region: Option<&str>,
    ) -> Result<Vec<CropRecord>, Box<dyn std::error::Error + Send + Sync>>;

    fn find_by_id(
        &self,
        crop_id: i64,
    ) -> Result<CropRecord, Box<dyn std::error::Error + Send + Sync>>;
}
