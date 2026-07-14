//! Ruby: `Domain::WorkRecord::Interactors::WorkRecordPhotoUploadCompleteInteractor`

use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::ports::ClockPort;
use crate::shared::validation::{from_errors, ErrorsInput};
use crate::work_record::dtos::work_record_create_input::record_invalid_field;
use crate::work_record::gateways::{
    photo_row_to_read, WorkRecordPhotoGateway, WorkRecordPhotoStatus,
};
use crate::work_record::interactors::private_plan_access;
use crate::work_record::policies::work_record_photo_policy::byte_size_allowed;
use crate::work_record::ports::WorkRecordPhotoUploadCompleteOutputPort;
use std::collections::BTreeMap;

pub struct WorkRecordPhotoUploadCompleteInteractor<'a, O, P, G, C> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    photo_gateway: &'a G,
    clock: &'a C,
    read_url_builder: &'a dyn Fn(i64, i64, i64) -> String,
}

impl<'a, O, P, G, C> WorkRecordPhotoUploadCompleteInteractor<'a, O, P, G, C>
where
    O: WorkRecordPhotoUploadCompleteOutputPort,
    P: CultivationPlanGateway,
    G: WorkRecordPhotoGateway,
    C: ClockPort,
{
    pub fn new(
        output_port: &'a mut O,
        plan_gateway: &'a P,
        photo_gateway: &'a G,
        clock: &'a C,
        read_url_builder: &'a dyn Fn(i64, i64, i64) -> String,
    ) -> Self {
        Self {
            output_port,
            plan_gateway,
            photo_gateway,
            clock,
            read_url_builder,
        }
    }

    pub fn call(
        &mut self,
        user_id: i64,
        plan_id: i64,
        work_record_id: i64,
        photo_id: i64,
        byte_size: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if !private_plan_access::access_allowed(self.plan_gateway, plan_id, user_id) {
            self.output_port.on_not_found();
            return Ok(());
        }

        if !byte_size_allowed(byte_size) {
            return Err(record_invalid_field(
                "byte_size",
                "plans.work_records.photos.errors.invalid_byte_size",
            )
            .into());
        }

        let row = match self
            .photo_gateway
            .find_for_record(plan_id, work_record_id, photo_id)
        {
            Ok(row) => row,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                return Err(RecordNotFoundError.into());
            }
            Err(err) => return Err(err),
        };

        if row.status != WorkRecordPhotoStatus::Pending {
            return Err(record_invalid_field(
                "status",
                "plans.work_records.photos.errors.already_completed",
            )
            .into());
        }

        let position = self
            .photo_gateway
            .count_ready_for_record(plan_id, work_record_id)?;

        let now = self.clock.now();
        let ready = self.photo_gateway.mark_ready(
            plan_id,
            work_record_id,
            photo_id,
            byte_size,
            position,
            now,
        )?;
        let url = (self.read_url_builder)(plan_id, work_record_id, photo_id);
        let read = photo_row_to_read(ready, url).ok_or_else(|| {
            record_invalid_field("photo", "plans.work_records.photos.errors.invalid_state")
        })?;
        self.output_port.on_success(read);
        Ok(())
    }

    pub fn call_rescuing(
        &mut self,
        user_id: i64,
        plan_id: i64,
        work_record_id: i64,
        photo_id: i64,
        byte_size: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.call(user_id, plan_id, work_record_id, photo_id, byte_size) {
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
