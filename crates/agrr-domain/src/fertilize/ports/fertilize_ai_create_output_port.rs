use crate::fertilize::dtos::{FertilizeAiCreateFailure, FertilizeAiCreateOutput};

pub trait FertilizeAiCreateOutputPort {
    fn on_success(&mut self, dto: FertilizeAiCreateOutput);
    fn on_failure(&mut self, dto: FertilizeAiCreateFailure);
}
