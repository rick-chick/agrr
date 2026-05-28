use crate::crop::entities::CropEntity;
use crate::shared::dtos::Error;

pub trait CropListReferenceEntitiesOutputPort {
    fn on_success(&mut self, crops: Vec<CropEntity>);
    fn on_failure(&mut self, error: Error);
}
