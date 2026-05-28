use crate::pest::dtos::{PestAiCreateFailure, PestAiCreateOutput};

pub trait PestAiCreateOutputPort {
    fn on_success(&mut self, output: PestAiCreateOutput);
    fn on_failure(&mut self, failure: PestAiCreateFailure);
}
