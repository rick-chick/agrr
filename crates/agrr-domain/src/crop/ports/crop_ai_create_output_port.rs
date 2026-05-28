use crate::crop::dtos::{CropAiCreateFailure, CropAiCreateOutput};

pub trait CropAiCreateOutputPort {
    fn on_success(&mut self, output: CropAiCreateOutput);
    fn on_failure(&mut self, error: CropAiCreateFailure);
}
