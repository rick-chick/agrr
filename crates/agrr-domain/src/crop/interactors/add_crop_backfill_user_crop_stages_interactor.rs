//! Backfill user crop stages from `source_crop_id` before add_crop candidates (plan-save parity).

use crate::crop::dtos::CropStageCopyInput;
use crate::crop::entities::CropEntity;
use crate::crop::gateways::{CropGateway, CropSourceCropLookupGateway};
use crate::crop::interactors::crop_stage_copy_interactor::CropStageCopyInteractor;
use crate::shared::ports::logger_port::LoggerPort;

pub struct AddCropBackfillUserCropStagesInteractor<'a, G, S, L> {
    crop_gateway: &'a G,
    source_crop_lookup: &'a S,
    logger: &'a L,
}

impl<'a, G, S, L> AddCropBackfillUserCropStagesInteractor<'a, G, S, L>
where
    G: CropGateway,
    S: CropSourceCropLookupGateway,
    L: LoggerPort,
{
    pub fn new(crop_gateway: &'a G, source_crop_lookup: &'a S, logger: &'a L) -> Self {
        Self {
            crop_gateway,
            source_crop_lookup,
            logger,
        }
    }

    pub fn call(
        &self,
        crop: &CropEntity,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if crop.is_reference {
            return Ok(());
        }

        let Some(source_crop_id) = self.source_crop_lookup.find_source_crop_id(crop.id)? else {
            return Ok(());
        };

        self.logger.info(&format!(
            "♻️ [AddCrop] Backfilling crop stages from reference crop {source_crop_id} to user crop {}",
            crop.id
        ));

        CropStageCopyInteractor::new(self.crop_gateway).call(CropStageCopyInput {
            reference_crop_id: source_crop_id,
            new_crop_id: crop.id,
        })
    }
}

#[cfg(test)]
mod interactors_add_crop_backfill_user_crop_stages_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/crop/interactors_add_crop_backfill_user_crop_stages_interactor_test.rs"
    ));
}
