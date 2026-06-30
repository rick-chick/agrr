//! Work record output ports.

use std::collections::BTreeMap;

use crate::work_record::dtos::WorkRecordRead;

pub trait WorkRecordCreateOutputPort {
    fn on_success(&mut self, record: WorkRecordRead);
    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        fallback_message: &str,
    );
    fn on_not_found(&mut self);
}

pub trait WorkRecordListOutputPort {
    fn on_success(&mut self, records: Vec<WorkRecordRead>);
    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        fallback_message: &str,
    );
    fn on_not_found(&mut self);
}

pub trait WorkRecordUpdateOutputPort {
    fn on_success(&mut self, record: WorkRecordRead);
    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        fallback_message: &str,
    );
    fn on_not_found(&mut self);
}

pub trait WorkRecordDestroyOutputPort {
    fn on_success(&mut self);
    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        fallback_message: &str,
    );
    fn on_not_found(&mut self);
}

pub(crate) mod work_hub_list_output_port;
pub use work_hub_list_output_port::WorkHubListOutputPort;
