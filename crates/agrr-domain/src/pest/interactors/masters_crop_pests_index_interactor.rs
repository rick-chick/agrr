//! Ruby: `Domain::Pest::Interactors::MastersCropPestsIndexInteractor`

use crate::pest::gateways::{CropPestListOrder, PestGateway};
use crate::pest::ports::MastersCropPestsIndexOutputPort;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::pest_policy;

pub struct MastersCropPestsIndexInteractor<'a, O, U, G> {
    output_port: &'a mut O,
    user_id: i64,
    user_lookup: &'a U,
    pest_gateway: &'a G,
}

impl<'a, O, U, G> MastersCropPestsIndexInteractor<'a, O, U, G>
where
    O: MastersCropPestsIndexOutputPort,
    U: UserLookupGateway,
    G: PestGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        user_lookup: &'a U,
        pest_gateway: &'a G,
    ) -> Self {
        Self {
            output_port,
            user_id,
            user_lookup,
            pest_gateway,
        }
    }

    pub fn call(
        &mut self,
        crop_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let filter = pest_policy::selectable_list_filter(&user);
        let accessible_pest_ids: Vec<i64> = self
            .pest_gateway
            .list_index_for_filter(&filter)?
            .into_iter()
            .map(|p| p.id)
            .collect();
        let pests = self.pest_gateway.list_pests_for_crop_filtered(
            crop_id,
            &accessible_pest_ids,
            CropPestListOrder::IdAsc,
        )?;
        self.output_port.on_success(pests);
        Ok(())
    }
}

#[cfg(test)]
mod interactors_masters_crop_pests_index_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pest/interactors_masters_crop_pests_index_interactor_test.rs"));
}
