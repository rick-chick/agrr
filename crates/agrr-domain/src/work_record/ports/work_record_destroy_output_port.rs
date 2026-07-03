use std::collections::BTreeMap;

use crate::shared::dtos::Error;
use crate::work_record::dtos::WorkRecordDestroyOutput;

#[derive(Debug)]
pub enum DestroyFailure {
    Error(Error),
}

pub trait WorkRecordDestroyOutputPort {
    fn on_success(&mut self, dto: WorkRecordDestroyOutput);
    fn on_failure(&mut self, error: DestroyFailure);
    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        fallback_message: &str,
    );
    fn on_not_found(&mut self);
}
