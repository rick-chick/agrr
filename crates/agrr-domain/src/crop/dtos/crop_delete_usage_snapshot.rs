/// Ruby: `Domain::Crop::Dtos::CropDeleteUsageSnapshot`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CropDeleteUsageSnapshot {
    pub cultivation_plan_crops_count: i32,
    pub free_crop_plans_count: i32,
    pub pesticides_count: i32,
}
