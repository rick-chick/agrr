use crate::field_cultivation::dtos::ClimateCropEntity;
use crate::shared::exceptions::RecordNotFoundError;

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

/// Helper to map RecordNotFound to None (Ruby rescue).
pub fn find_crop_optional(
    gateway: &dyn FieldCultivationCropGateway,
    crop_id: i64,
) -> Option<ClimateCropEntity> {
    match gateway.find_by_id(crop_id) {
        Ok(entity) => Some(entity),
        Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => None,
        Err(err) => panic!("unexpected crop gateway error: {err}"),
    }
}
