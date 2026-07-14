//! Read model for work record photos in API responses.

use time::OffsetDateTime;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WorkRecordPhotoRead {
    pub id: i64,
    pub work_record_id: i64,
    pub position: i32,
    pub content_type: String,
    pub byte_size: i64,
    pub url: String,
    pub created_at: OffsetDateTime,
}
