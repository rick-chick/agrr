/// Ruby: `Domain::Crop::Dtos::CropDeleteUsage`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CropDeleteUsage {
    pub cultivation_plan_crops_count: i32,
    pub free_crop_plans_count: i32,
    pub pesticides_count: i32,
}

impl CropDeleteUsage {
    pub fn new(cultivation_plan_crops_count: i32, free_crop_plans_count: i32, pesticides_count: i32) -> Self {
        Self { cultivation_plan_crops_count, free_crop_plans_count, pesticides_count }
    }
}
