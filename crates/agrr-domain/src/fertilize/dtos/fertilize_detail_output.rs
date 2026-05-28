use crate::fertilize::dtos::FertilizeDisplay;
use crate::fertilize::entities::FertilizeEntity;

/// Ruby: `Domain::Fertilize::Dtos::FertilizeDetailOutput`
#[derive(Debug, Clone)]
pub struct FertilizeDetailOutput {
    pub display_dto: FertilizeDisplay,
}

impl FertilizeDetailOutput {
    pub fn new(fertilize_entity: &FertilizeEntity) -> Self {
        Self {
            display_dto: FertilizeDisplay::new(fertilize_entity),
        }
    }
}
