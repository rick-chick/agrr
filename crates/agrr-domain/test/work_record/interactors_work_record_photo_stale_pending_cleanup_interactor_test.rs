// Tests for `interactors/work_record_photo_stale_pending_cleanup_interactor.rs`

use std::sync::Mutex;

use crate::shared::ports::ClockPort;
use crate::work_record::gateways::{
    WorkRecordPhotoGateway, WorkRecordPhotoObjectStoreGateway, WorkRecordPhotoRow,
    WorkRecordPhotoStatus,
};
use crate::work_record::interactors::WorkRecordPhotoStalePendingCleanupInteractor;
use crate::work_record::policies::work_record_photo_policy::PENDING_UPLOAD_CLEANUP_TTL_SECS;
use time::{Date, Duration, OffsetDateTime};

struct FixedClock(OffsetDateTime);

impl ClockPort for FixedClock {
    fn today(&self) -> Date {
        self.0.date()
    }

    fn now(&self) -> OffsetDateTime {
        self.0
    }
}

struct StubPhotoGateway {
    deleted: Mutex<Vec<WorkRecordPhotoRow>>,
}

impl WorkRecordPhotoGateway for StubPhotoGateway {
    fn count_for_record(
        &self,
        _: i64,
        _: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
        Ok(0)
    }

    fn count_ready_for_record(
        &self,
        _: i64,
        _: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
        Ok(0)
    }

    fn insert_pending(
        &self,
        _: i64,
        _: i64,
        _: &str,
        _: &str,
        _: OffsetDateTime,
    ) -> Result<WorkRecordPhotoRow, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_for_record(
        &self,
        _: i64,
        _: i64,
        _: i64,
    ) -> Result<WorkRecordPhotoRow, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn mark_ready(
        &self,
        _: i64,
        _: i64,
        _: i64,
        _: i64,
        _: i32,
        _: OffsetDateTime,
    ) -> Result<WorkRecordPhotoRow, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn delete(
        &self,
        _: i64,
        _: i64,
        _: i64,
    ) -> Result<Option<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn list_ready_for_plan(
        &self,
        _: i64,
        _: &[i64],
    ) -> Result<Vec<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(Vec::new())
    }

    fn work_record_exists(
        &self,
        _: i64,
        _: i64,
    ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
        Ok(true)
    }

    fn delete_stale_pending_older_than(
        &self,
        _: OffsetDateTime,
    ) -> Result<Vec<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.deleted.lock().unwrap().clone())
    }
}

struct StubObjectStore {
    deleted_keys: Mutex<Vec<String>>,
}

impl WorkRecordPhotoObjectStoreGateway for StubObjectStore {
    fn write_object(
        &self,
        _: &str,
        _: &str,
        _: &[u8],
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn read_object(
        &self,
        _: &str,
    ) -> Result<Option<Vec<u8>>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(None)
    }

    fn delete_object(
        &self,
        storage_key: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.deleted_keys.lock().unwrap().push(storage_key.into());
        Ok(())
    }
}

#[test]
fn stale_pending_cleanup_deletes_metadata_and_attempts_object_delete() {
    let now = OffsetDateTime::now_utc();
    let stale_row = WorkRecordPhotoRow {
        id: 7,
        work_record_id: 2,
        cultivation_plan_id: 1,
        storage_key: "work_record_photos/1/2/stale.jpg".into(),
        content_type: Some("image/jpeg".into()),
        byte_size: None,
        position: None,
        status: WorkRecordPhotoStatus::Pending,
        created_at: now - Duration::seconds(PENDING_UPLOAD_CLEANUP_TTL_SECS + 60),
        updated_at: now,
    };
    let photo_gateway = StubPhotoGateway {
        deleted: Mutex::new(vec![stale_row.clone()]),
    };
    let object_store = StubObjectStore {
        deleted_keys: Mutex::new(Vec::new()),
    };
    let clock = FixedClock(now);

    let interactor =
        WorkRecordPhotoStalePendingCleanupInteractor::new(&photo_gateway, &object_store, &clock);
    let removed = interactor.call().expect("cleanup");
    assert_eq!(removed.len(), 1);
    assert_eq!(removed[0].id, 7);
    let deleted_keys = object_store.deleted_keys.lock().unwrap().clone();
    assert_eq!(deleted_keys, vec!["work_record_photos/1/2/stale.jpg".to_string()]);
}
