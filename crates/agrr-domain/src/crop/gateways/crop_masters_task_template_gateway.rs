use crate::crop::dtos::CropTaskTemplatePersistAttributes;
use crate::crop::entities::CropTaskTemplateEntity;

/// Ruby: crop masters task template persistence (separate from agricultural_task gateway)
pub trait CropMastersTaskTemplateGateway: Send + Sync {
    fn find_by_agricultural_task_id_and_crop_id(
        &self,
        agricultural_task_id: i64,
        crop_id: i64,
    ) -> Result<Option<CropTaskTemplateEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn create_detail(
        &self,
        crop_id: i64,
        agricultural_task_id: i64,
        attributes: CropTaskTemplatePersistAttributes,
    ) -> Result<CropTaskTemplateEntity, Box<dyn std::error::Error + Send + Sync>>;
}
