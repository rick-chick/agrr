use crate::agricultural_task::entities::CropTaskTemplateLinkEntity;
use crate::shared::attr::AttrMap;

/// Ruby: `Domain::AgriculturalTask::Gateways::CropTaskTemplateGateway`
pub trait CropTaskTemplateGateway: Send + Sync {
    fn list_by_agricultural_task_id(
        &self,
        agricultural_task_id: i64,
    ) -> Result<Vec<CropTaskTemplateLinkEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn find_by_agricultural_task_id_and_crop_id(
        &self,
        agricultural_task_id: i64,
        crop_id: i64,
    ) -> Result<Option<CropTaskTemplateLinkEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        agricultural_task_id: i64,
        crop_id: i64,
        attrs: AttrMap,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn delete(
        &self,
        agricultural_task_id: i64,
        crop_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
