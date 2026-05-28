//! Narrow port for crop create limit checks during plan save (subset of `CropGateway`).

pub trait PlanSaveCropLimitGateway: Send + Sync {
    fn count_user_owned_non_reference_crops(
        &self,
        user_id: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>>;
}
