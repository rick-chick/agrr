use crate::farm::entities::FarmEntity;
use crate::shared::dtos::Error;

pub trait FarmListReferenceForRegionOutputPort {
    fn on_success(&mut self, farms: Vec<FarmEntity>);
    fn on_failure(&mut self, error: Error);
}
