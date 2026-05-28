/// Ruby: `Domain::Farm::Dtos::FarmDeleteUsage`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FarmDeleteUsage {
    pub free_crop_plans_count: i32,
}

impl FarmDeleteUsage {
    pub fn new(free_crop_plans_count: i32) -> Self {
        Self {
            free_crop_plans_count,
        }
    }
}
