//! Ruby: `Domain::Farm::Interactors::FarmListInteractor`

use crate::farm::dtos::FarmListInput;
use crate::farm::gateways::FarmGateway;
use crate::farm::ports::{FarmListOutputPort, FarmListSuccess, ListFailure};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub struct FarmListInteractor<'a, G, O> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
}

impl<'a, G, O> FarmListInteractor<'a, G, O>
where
    G: FarmGateway,
    O: FarmListOutputPort,
{
    pub fn new(output_port: &'a mut O, user_id: i64, gateway: &'a G) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
        }
    }

    pub fn call(
        &mut self,
        input: Option<FarmListInput>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let input = input.unwrap_or_default();
        let result = if input.is_admin {
            match (
                self.gateway.list_user_and_reference_farms(self.user_id),
                self.gateway.list_reference_farms(),
            ) {
                (Ok(farms), Ok(reference_farms)) => FarmListSuccess {
                    farms,
                    reference_farms,
                },
                (Err(err), _) | (_, Err(err)) => {
                    return Self::handle_err(&mut self.output_port, err);
                }
            }
        } else {
            match self.gateway.list_user_owned_farms(self.user_id) {
                Ok(farms) => FarmListSuccess {
                    farms,
                    reference_farms: vec![],
                },
                Err(err) => return Self::handle_err(&mut self.output_port, err),
            }
        };

        self.output_port.on_success(result);
        Ok(())
    }

    fn handle_err(
        output_port: &mut O,
        err: Box<dyn std::error::Error + Send + Sync>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
            output_port.on_failure(ListFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }
        if err.downcast_ref::<crate::shared::exceptions::RecordNotFoundError>().is_some() {
            output_port.on_failure(ListFailure::Error(Error::new(
                "Record not found".to_string(),
            )));
            return Ok(());
        }
        match err.downcast::<RecordInvalidError>() {
            Ok(record_invalid) => {
                output_port.on_failure(ListFailure::Error(Error::new(
                    record_invalid.to_string(),
                )));
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}

#[cfg(test)]
mod interactors_farm_list_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/farm/interactors_farm_list_interactor_test.rs"));
}
