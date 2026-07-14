//! SQLite metadata port for work record photos.

use time::OffsetDateTime;

use crate::work_record::dtos::WorkRecordPhotoRead;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WorkRecordPhotoStatus {
    Pending,
    Ready,
}

impl WorkRecordPhotoStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Pending => "pending",
            Self::Ready => "ready",
        }
    }

    pub fn parse(raw: &str) -> Option<Self> {
        match raw {
            "pending" => Some(Self::Pending),
            "ready" => Some(Self::Ready),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WorkRecordPhotoRow {
    pub id: i64,
    pub work_record_id: i64,
    pub cultivation_plan_id: i64,
    pub storage_key: String,
    pub content_type: Option<String>,
    pub byte_size: Option<i64>,
    pub position: Option<i32>,
    pub status: WorkRecordPhotoStatus,
    pub created_at: OffsetDateTime,
    pub updated_at: OffsetDateTime,
}

pub trait WorkRecordPhotoGateway: Send + Sync {
    fn count_for_record(
        &self,
        plan_id: i64,
        work_record_id: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>>;

    fn count_ready_for_record(
        &self,
        plan_id: i64,
        work_record_id: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>>;

    fn insert_pending(
        &self,
        plan_id: i64,
        work_record_id: i64,
        storage_key: &str,
        content_type: &str,
        now: OffsetDateTime,
    ) -> Result<WorkRecordPhotoRow, Box<dyn std::error::Error + Send + Sync>>;

    fn find_for_record(
        &self,
        plan_id: i64,
        work_record_id: i64,
        photo_id: i64,
    ) -> Result<WorkRecordPhotoRow, Box<dyn std::error::Error + Send + Sync>>;

    fn mark_ready(
        &self,
        plan_id: i64,
        work_record_id: i64,
        photo_id: i64,
        byte_size: i64,
        position: i32,
        now: OffsetDateTime,
    ) -> Result<WorkRecordPhotoRow, Box<dyn std::error::Error + Send + Sync>>;

    fn delete(
        &self,
        plan_id: i64,
        work_record_id: i64,
        photo_id: i64,
    ) -> Result<Option<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_ready_for_plan(
        &self,
        plan_id: i64,
        work_record_ids: &[i64],
    ) -> Result<Vec<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>>;

    fn work_record_exists(
        &self,
        plan_id: i64,
        work_record_id: i64,
    ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>>;

    fn delete_stale_pending_older_than(
        &self,
        cutoff: OffsetDateTime,
    ) -> Result<Vec<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>>;
}

pub trait WorkRecordPhotoObjectStoreGateway: Send + Sync {
    fn write_object(
        &self,
        storage_key: &str,
        content_type: &str,
        bytes: &[u8],
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn read_object(
        &self,
        storage_key: &str,
    ) -> Result<Option<Vec<u8>>, Box<dyn std::error::Error + Send + Sync>>;

    fn delete_object(
        &self,
        storage_key: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}

pub fn photo_row_to_read(row: WorkRecordPhotoRow, url: String) -> Option<WorkRecordPhotoRead> {
    if row.status != WorkRecordPhotoStatus::Ready {
        return None;
    }
    Some(WorkRecordPhotoRead {
        id: row.id,
        work_record_id: row.work_record_id,
        position: row.position?,
        content_type: row.content_type.unwrap_or_else(|| "image/jpeg".into()),
        byte_size: row.byte_size?,
        url,
        created_at: row.created_at,
    })
}
