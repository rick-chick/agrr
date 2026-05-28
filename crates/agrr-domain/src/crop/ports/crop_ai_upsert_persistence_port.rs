use crate::crop::dtos::{CropAiCreateFailure, CropAiCreateOutput};
use crate::shared::policies::crop_policy::CropRecordAccessPolicy;
use crate::shared::reference_record_access_filter::ReferenceRecordAccessFilter;
use crate::shared::user::User;
use serde_json::Value;

pub trait CropAiUpsertPersistencePort: Send + Sync {
    fn upsert(
        &self,
        user: &User,
        crop_name: &str,
        variety: Option<&str>,
        crop_info: Value,
        access_filter: ReferenceRecordAccessFilter<CropRecordAccessPolicy>,
    ) -> Result<CropAiCreateOutput, CropAiCreateFailure>;
}
