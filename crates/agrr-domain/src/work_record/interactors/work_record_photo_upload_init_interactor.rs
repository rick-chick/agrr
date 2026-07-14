//! Ruby: `Domain::WorkRecord::Interactors::WorkRecordPhotoUploadInitInteractor`

use time::Duration;

use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::ports::ClockPort;
use crate::shared::validation::{from_errors, ErrorsInput};
use crate::work_record::dtos::work_record_create_input::record_invalid_field;
use crate::work_record::dtos::WorkRecordPhotoUploadInitOutput;
use crate::work_record::gateways::WorkRecordPhotoGateway;
use crate::work_record::interactors::private_plan_access;
use crate::work_record::policies::work_record_photo_policy::{
    content_type_allowed, extension_for_content_type, MAX_PHOTOS_PER_RECORD, UPLOAD_URL_TTL_SECS,
};
use crate::work_record::ports::WorkRecordPhotoUploadInitOutputPort;

pub struct WorkRecordPhotoUploadInitInteractor<'a, O, P, G, C> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    photo_gateway: &'a G,
    clock: &'a C,
    upload_url_builder: &'a dyn Fn(i64, i64, i64) -> String,
}

impl<'a, O, P, G, C> WorkRecordPhotoUploadInitInteractor<'a, O, P, G, C>
where
    O: WorkRecordPhotoUploadInitOutputPort,
    P: CultivationPlanGateway,
    G: WorkRecordPhotoGateway,
    C: ClockPort,
{
    pub fn new(
        output_port: &'a mut O,
        plan_gateway: &'a P,
        photo_gateway: &'a G,
        clock: &'a C,
        upload_url_builder: &'a dyn Fn(i64, i64, i64) -> String,
    ) -> Self {
        Self {
            output_port,
            plan_gateway,
            photo_gateway,
            clock,
            upload_url_builder,
        }
    }

    pub fn call(
        &mut self,
        user_id: i64,
        plan_id: i64,
        work_record_id: i64,
        content_type: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if !private_plan_access::access_allowed(self.plan_gateway, plan_id, user_id) {
            self.output_port.on_not_found();
            return Ok(());
        }

        if !content_type_allowed(content_type) {
            return Err(record_invalid_field(
                "content_type",
                "plans.work_records.photos.errors.invalid_content_type",
            )
            .into());
        }

        if !self
            .photo_gateway
            .work_record_exists(plan_id, work_record_id)?
        {
            return Err(RecordNotFoundError.into());
        }

        let now = self.clock.now();
        let ext = extension_for_content_type(content_type);
        let storage_key = format!(
            "work_record_photos/{plan_id}/{work_record_id}/{}.{ext}",
            now.unix_timestamp_nanos()
        );

        let row = match self.photo_gateway.insert_pending_under_limit(
            plan_id,
            work_record_id,
            &storage_key,
            content_type,
            MAX_PHOTOS_PER_RECORD,
            now,
        )? {
            Some(row) => row,
            None => {
                return Err(record_invalid_field(
                    "photos",
                    "plans.work_records.photos.errors.limit_exceeded",
                )
                .into());
            }
        };

        let upload_expires_at = now + Duration::seconds(UPLOAD_URL_TTL_SECS);
        let upload_url = (self.upload_url_builder)(plan_id, work_record_id, row.id);

        self.output_port.on_success(WorkRecordPhotoUploadInitOutput {
            photo_id: row.id,
            upload_url,
            upload_method: "PUT".into(),
            upload_expires_at,
            content_type: content_type.into(),
        });
        Ok(())
    }

    pub fn call_rescuing(
        &mut self,
        user_id: i64,
        plan_id: i64,
        work_record_id: i64,
        content_type: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.call(user_id, plan_id, work_record_id, content_type) {
            Ok(()) => Ok(()),
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                let invalid = err.downcast_ref::<RecordInvalidError>().unwrap();
                self.output_port.on_record_invalid(
                    from_errors(ErrorsInput::ValidationErrors(
                        invalid.errors.as_ref().expect("record invalid"),
                    )),
                    &invalid.to_string(),
                );
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_not_found();
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}

#[cfg(test)]
mod interactors_work_record_photo_upload_init_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/work_record/interactors_work_record_photo_upload_init_interactor_test.rs"
    ));
}
