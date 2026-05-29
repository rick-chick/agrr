//! Ruby: `Domain::Pesticide::Interactors::PesticideListInteractor`

use crate::pesticide::gateways::PesticideGateway;
use crate::pesticide::ports::{ListFailure, PesticideListOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::mappers::referencable_list_row_mapper::map_records;
use crate::shared::policies::pesticide_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub struct PesticideListInteractor<'a, G, O, U> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a U,
}

impl<'a, G, O, U> PesticideListInteractor<'a, G, O, U>
where
    G: PesticideGateway,
    O: PesticideListOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            user_lookup,
        }
    }

    pub fn call(&mut self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let filter = pesticide_policy::index_list_filter(&user);
        match self.gateway.list_index_for_filter(&filter) {
            Ok(records) => {
                let rows = map_records(&user, records);
                self.output_port.on_success(rows);
                Ok(())
            }
            Err(err) => {
                if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
                    self.output_port.on_failure(ListFailure::Policy(PolicyPermissionDenied));
                    return Ok(());
                }
                if err.downcast_ref::<crate::shared::exceptions::RecordNotFoundError>().is_some()
                {
                    self.output_port.on_failure(ListFailure::Error(Error::new(
                        "Record not found".to_string(),
                    )));
                    return Ok(());
                }
                match err.downcast::<RecordInvalidError>() {
                    Ok(record_invalid) => {
                        self.output_port.on_failure(ListFailure::Error(Error::new(
                            record_invalid.to_string(),
                        )));
                        Ok(())
                    }
                    Err(err) => Err(err),
                }
            }
        }
    }
}

#[cfg(test)]
mod interactors_pesticide_list_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pesticide/interactors_pesticide_list_interactor_test.rs"));
}
