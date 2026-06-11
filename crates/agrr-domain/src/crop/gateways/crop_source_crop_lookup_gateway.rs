//! Lookup `crops.source_crop_id` for add_crop stage backfill (plan-save parity).

pub trait CropSourceCropLookupGateway: Send + Sync {
    fn find_source_crop_id(
        &self,
        crop_id: i64,
    ) -> Result<Option<i64>, Box<dyn std::error::Error + Send + Sync>>;
}
