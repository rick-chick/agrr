//! Ruby: `Domain::WorkRecord::Interactors::WorkRecordPhotoDestroyInteractor`

use std::collections::BTreeMap;

use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::validation::{from_errors, ErrorsInput};
use crate::work_record::gateways::{
    WorkRecordPhotoGateway, WorkRecordPhotoObjectStoreGateway, WorkRecordPhotoStatus,
};
use crate::work_record::interactors::private_plan_access;
use crate::work_record::ports::WorkRecordPhotoDestroyOutputPort;

pub struct WorkRecordPhotoDestroyInteractor<'a, O, P, G, S: ?Sized> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    photo_gateway: &'a G,
    object_store: &'a S,
}

impl<'a, O, P, G, S> WorkRecordPhotoDestroyInteractor<'a, O, P, G, S>
where
    O: WorkRecordPhotoDestroyOutputPort,
    P: CultivationPlanGateway,
    G: WorkRecordPhotoGateway,
    S: WorkRecordPhotoObjectStoreGateway + ?Sized,
{
    pub fn new(
        output_port: &'a mut O,
        plan_gateway: &'a P,
        photo_gateway: &'a G,
        object_store: &'a S,
    ) -> Self {
        Self {
            output_port,
            plan_gateway,
            photo_gateway,
            object_store,
        }
    }

    pub fn call(
        &mut self,
        user_id: i64,
        plan_id: i64,
        work_record_id: i64,
        photo_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if !private_plan_access::access_allowed(self.plan_gateway, plan_id, user_id) {
            self.output_port.on_not_found();
            return Ok(());
        }

        let deleted = match self
            .photo_gateway
            .delete(plan_id, work_record_id, photo_id)
        {
            Ok(row) => row,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                return Err(RecordNotFoundError.into());
            }
            Err(err) => return Err(err),
        };

        let Some(row) = deleted else {
            return Err(RecordNotFoundError.into());
        };

        if row.status == WorkRecordPhotoStatus::Ready {
            self.object_store.delete_object(&row.storage_key)?;
        }

        self.output_port.on_success();
        Ok(())
    }

    pub fn call_rescuing(
        &mut self,
        user_id: i64,
        plan_id: i64,
        work_record_id: i64,
        photo_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.call(user_id, plan_id, work_record_id, photo_id) {
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
