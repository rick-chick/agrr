/// Ruby: `Domain::Shared::Dtos::PestCropAccessibleCropsFilter`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PestCropAccessibleCropsFilter {
    reference_pest: bool,
    pub scoped_user_id: Option<i64>,
    pub region: Option<String>,
}

impl PestCropAccessibleCropsFilter {
    pub fn new(
        reference_pest: bool,
        scoped_user_id: Option<i64>,
        region: Option<String>,
    ) -> Self {
        Self {
            reference_pest,
            scoped_user_id,
            region,
        }
    }

    pub fn reference_pest(&self) -> bool {
        self.reference_pest
    }
}
