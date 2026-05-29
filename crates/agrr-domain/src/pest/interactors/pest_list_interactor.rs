//! Ruby: `Domain::Pest::Interactors::PestListInteractor`

use crate::pest::gateways::PestGateway;
use crate::pest::ports::{ListFailure, PestListOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::mappers::referencable_list_row_mapper::map_records;
use crate::shared::policies::pest_policy;

pub struct PestListInteractor<'a, G, O, U> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a U,
}

impl<'a, G, O, U> PestListInteractor<'a, G, O, U>
where
    G: PestGateway,
    O: PestListOutputPort,
    U: UserLookupGateway,
{
    pub fn new(output_port: &'a mut O, user_id: i64, gateway: &'a G, user_lookup: &'a U) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            user_lookup,
        }
    }

    pub fn call(&mut self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let filter = pest_policy::index_list_filter(&user);
        match self.gateway.list_index_for_filter(&filter) {
            Ok(pests) => {
                let rows = map_records(&user, pests);
                self.output_port.on_success(rows);
                Ok(())
            }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(record_invalid) => {
                    self.output_port.on_failure(ListFailure::Error(Error::new(
                        record_invalid.to_string(),
                    )));
                    Ok(())
                }
                Err(err) => Err(err),
            },
        }
    }
}

#[cfg(test)]
mod interactors_pest_list_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pest/interactors_pest_list_interactor_test.rs"));
}
