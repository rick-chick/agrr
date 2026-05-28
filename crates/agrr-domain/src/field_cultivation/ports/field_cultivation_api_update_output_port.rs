use crate::field_cultivation::dtos::FieldCultivationApiUpdateOutput;
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;

pub enum FieldCultivationUpdateFailure {
    Message(Error),
    RecordInvalid(RecordInvalidError),
}

pub trait FieldCultivationApiUpdateOutputPort {
    fn on_success(&mut self, dto: FieldCultivationApiUpdateOutput);
    fn on_failure(&mut self, error: FieldCultivationUpdateFailure);
}
