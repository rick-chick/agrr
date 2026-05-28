use crate::public_plan::dtos::PublicPlanCrop;
use crate::shared::exceptions::RecordInvalidError;

/// Reference crop listing for no-crops view (Ruby: `@crop_gateway.list_by_is_reference`).
pub trait PublicPlanCropGateway: Send + Sync {
    fn list_by_is_reference(
        &self,
        is_reference: bool,
        region: Option<&str>,
    ) -> Result<Vec<PublicPlanCrop>, RecordInvalidError>;
}
