use std::collections::BTreeMap;

use crate::work_record::dtos::{WorkRecordPhotoRead, WorkRecordPhotoUploadInitOutput};

pub trait WorkRecordPhotoUploadInitOutputPort {
    fn on_success(&mut self, output: WorkRecordPhotoUploadInitOutput);
    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        fallback_message: &str,
    );
    fn on_not_found(&mut self);
}

pub trait WorkRecordPhotoUploadCompleteOutputPort {
    fn on_success(&mut self, photo: WorkRecordPhotoRead);
    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        fallback_message: &str,
    );
    fn on_not_found(&mut self);
}

pub trait WorkRecordPhotoDestroyOutputPort {
    fn on_success(&mut self);
    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        fallback_message: &str,
    );
    fn on_not_found(&mut self);
}
