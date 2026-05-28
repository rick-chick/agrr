use crate::pest::entities::CropPestLinkEntity;

/// Ruby: `Domain::Pest::Gateways::CropPestGateway`
pub trait CropPestGateway: Send + Sync {
    fn find_by_crop_id_and_pest_id(
        &self,
        crop_id: i64,
        pest_id: i64,
    ) -> Result<Option<CropPestLinkEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_by_pest_id(
        &self,
        pest_id: i64,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        crop_id: i64,
        pest_id: i64,
    ) -> Result<CropPestLinkEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn delete(
        &self,
        crop_id: i64,
        pest_id: i64,
    ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>>;
}
