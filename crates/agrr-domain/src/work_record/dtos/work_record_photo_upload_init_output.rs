//! Output from upload-init interactor.

use time::OffsetDateTime;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WorkRecordPhotoUploadInitOutput {
    pub photo_id: i64,
    pub upload_url: String,
    pub upload_method: String,
    pub upload_expires_at: OffsetDateTime,
    pub content_type: String,
}
