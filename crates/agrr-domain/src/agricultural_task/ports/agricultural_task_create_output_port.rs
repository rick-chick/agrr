use crate::agricultural_task::entities::AgriculturalTaskEntity;
use crate::shared::dtos::Error;

pub trait AgriculturalTaskCreateOutputPort {
    fn on_success(&mut self, entity: AgriculturalTaskEntity);
    fn on_failure(&mut self, error: Error);
}
