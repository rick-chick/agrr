use crate::shared::record_ref::RecordRef;

/// Minimal crop surface for masters nested pesticide index.
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

/// Ruby: crop gateway `find_by_id` used by `MastersCropPesticidesIndexInteractor`
pub trait CropGateway: Send + Sync {
    fn find_by_id(
        &self,
        crop_id: i64,
    ) -> Result<CropRecord, Box<dyn std::error::Error + Send + Sync>>;
}
