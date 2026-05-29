//! Ruby: `Domain::Pest::Interactors::PestLinkToCropInteractor`

use crate::pest::entities::PestEntity;
use crate::pest::gateways::{CropGateway, CropPestGateway, PestGateway};
use crate::shared::exceptions::RecordNotFoundError;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PestLinkToCropOutcome {
    Linked,
    AlreadyLinked,
    MissingCrop,
    MissingPest,
}

pub struct PestLinkToCropInteractor<'a, PG, CPG, CG> {
    pest_gateway: &'a PG,
    crop_pest_gateway: &'a CPG,
    crop_gateway: &'a CG,
}

impl<'a, PG, CPG, CG> PestLinkToCropInteractor<'a, PG, CPG, CG>
where
    PG: PestGateway,
    CPG: CropPestGateway,
    CG: CropGateway,
{
    pub fn new(pest_gateway: &'a PG, crop_pest_gateway: &'a CPG, crop_gateway: &'a CG) -> Self {
        Self {
            pest_gateway,
            crop_pest_gateway,
            crop_gateway,
        }
    }

    pub fn call(
        &self,
        crop_id: i64,
        pest_id: i64,
    ) -> Result<PestLinkToCropOutcome, Box<dyn std::error::Error + Send + Sync>> {
        if self.crop_gateway.find_by_id(crop_id)?.is_none() {
            return Ok(PestLinkToCropOutcome::MissingCrop);
        }

        let pest_entity = match self.pest_gateway.find_by_id(pest_id) {
            Ok(entity) => entity,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                return Ok(PestLinkToCropOutcome::MissingPest);
            }
            Err(err) => return Err(err),
        };

        if self
            .crop_pest_gateway
            .find_by_crop_id_and_pest_id(crop_id, pest_entity.id)?
            .is_some()
        {
            return Ok(PestLinkToCropOutcome::AlreadyLinked);
        }

        self.crop_pest_gateway.create(crop_id, pest_entity.id)?;
        Ok(PestLinkToCropOutcome::Linked)
    }
}

#[cfg(test)]
mod interactors_pest_link_to_crop_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pest/interactors_pest_link_to_crop_interactor_test.rs"));
}
