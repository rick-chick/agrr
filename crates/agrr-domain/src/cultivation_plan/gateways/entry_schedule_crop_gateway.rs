//! Ruby: `Domain::Crop::Gateways::CropGateway#entry_schedule_ordered_stage_rows`

use crate::cultivation_plan::interactors::entry_schedule::CropStageSnapshot;

pub trait EntryScheduleCropGateway: Send + Sync {
    fn entry_schedule_ordered_stage_rows(
        &self,
        crop_id: i64,
    ) -> Result<Vec<CropStageSnapshot>, Box<dyn std::error::Error + Send + Sync>>;
}
