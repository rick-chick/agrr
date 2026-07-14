//! Work record output ports.

use std::collections::BTreeMap;

use crate::work_record::dtos::WorkRecordRead;

pub(crate) mod work_hub_list_output_port;
pub(crate) mod work_record_destroy_output_port;
pub(crate) mod work_record_photo_output_ports;

pub use work_hub_list_output_port::WorkHubListOutputPort;
pub use work_record_destroy_output_port::{DestroyFailure, WorkRecordDestroyOutputPort};
pub use work_record_photo_output_ports::{
    WorkRecordPhotoDestroyOutputPort, WorkRecordPhotoUploadCompleteOutputPort,
    WorkRecordPhotoUploadInitOutputPort,
};

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
