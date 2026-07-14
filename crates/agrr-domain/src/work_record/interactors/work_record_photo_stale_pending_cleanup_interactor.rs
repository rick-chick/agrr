//! Ruby: `Domain::WorkRecord::Interactors::WorkRecordPhotoStalePendingCleanupInteractor`

use time::Duration;

use crate::shared::ports::ClockPort;
use crate::work_record::gateways::{
    WorkRecordPhotoGateway, WorkRecordPhotoObjectStoreGateway, WorkRecordPhotoRow,
};
use crate::work_record::policies::work_record_photo_policy::PENDING_UPLOAD_CLEANUP_TTL_SECS;

pub struct WorkRecordPhotoStalePendingCleanupInteractor<'a, G, S: ?Sized, C> {
    photo_gateway: &'a G,
    object_store: &'a S,
    clock: &'a C,
}

impl<'a, G, S, C> WorkRecordPhotoStalePendingCleanupInteractor<'a, G, S, C>
where
    G: WorkRecordPhotoGateway,
    S: WorkRecordPhotoObjectStoreGateway + ?Sized,
    C: ClockPort,
{
    pub fn new(photo_gateway: &'a G, object_store: &'a S, clock: &'a C) -> Self {
        Self {
            photo_gateway,
            object_store,
            clock,
        }
    }

    pub fn call(
        &self,
    ) -> Result<Vec<WorkRecordPhotoRow>, Box<dyn std::error::Error + Send + Sync>> {
        let cutoff = self.clock.now()
            - Duration::seconds(PENDING_UPLOAD_CLEANUP_TTL_SECS);
        let deleted = self.photo_gateway.delete_stale_pending_older_than(cutoff)?;
        for row in &deleted {
            let _ = self.object_store.delete_object(&row.storage_key);
        }
        Ok(deleted)
    }
}

#[cfg(test)]
mod interactors_work_record_photo_stale_pending_cleanup_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/work_record/interactors_work_record_photo_stale_pending_cleanup_interactor_test.rs"
    ));
}
