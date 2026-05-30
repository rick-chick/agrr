use crate::field_cultivation::dtos::ClimateCropEntity;

/// Narrow crop read port for climate UC.
pub trait FieldCultivationCropGateway: Send + Sync {
    fn find_by_id(
        &self,
        crop_id: i64,
    ) -> Result<ClimateCropEntity, Box<dyn std::error::Error + Send + Sync>>;
}

impl FieldCultivationCropGateway for &dyn FieldCultivationCropGateway {
    fn find_by_id(
        &self,
        crop_id: i64,
    ) -> Result<ClimateCropEntity, Box<dyn std::error::Error + Send + Sync>> {
        (*self).find_by_id(crop_id)
    }
}
