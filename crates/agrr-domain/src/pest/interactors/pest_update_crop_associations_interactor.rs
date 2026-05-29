//! Ruby: `Domain::Pest::Interactors::PestUpdateCropAssociationsInteractor`

use crate::pest::dtos::PestCropAssociationSyncResult;
use crate::pest::gateways::CropPestGateway;
use crate::pest::services::CropPestAssociationSync;

pub struct PestUpdateCropAssociationsInteractor<'a, G> {
    sync: CropPestAssociationSync<'a, G>,
}

impl<'a, G: CropPestGateway> PestUpdateCropAssociationsInteractor<'a, G> {
    pub fn new(crop_pest_gateway: &'a G) -> Self {
        Self {
            sync: CropPestAssociationSync::new(crop_pest_gateway),
        }
    }

    pub fn call(
        &self,
        pest_id: i64,
        crop_ids: &[i64],
    ) -> Result<PestCropAssociationSyncResult, Box<dyn std::error::Error + Send + Sync>> {
        self.sync.replace_all(pest_id, crop_ids)
    }
}

#[cfg(test)]
mod interactors_pest_update_crop_associations_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pest/interactors_pest_update_crop_associations_interactor_test.rs"));
}
