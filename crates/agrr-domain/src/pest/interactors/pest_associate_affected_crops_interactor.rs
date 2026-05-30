//! Ruby: `Domain::Pest::Interactors::PestAssociateAffectedCropsInteractor`

use crate::pest::gateways::{CropGateway, PestGateway};
use crate::pest::mappers::{extract_crop_ids, extract_crop_names};
use crate::pest::policies::select_id_for_pest_ai_name_fallback;
use crate::pest::services::{CropPestAssociationSync, FilterAssociableCropIds};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::ports::LoggerPort;
use serde_json::Value;

pub struct PestAssociateAffectedCropsInteractor<'a, PG, CG, CPG, U, L> {
    user_id: i64,
    user_lookup: &'a U,
    pest_gateway: &'a PG,
    crop_gateway: &'a CG,
    association_sync: CropPestAssociationSync<'a, CPG>,
    logger: &'a L,
}

impl<'a, PG, CG, CPG, U, L> PestAssociateAffectedCropsInteractor<'a, PG, CG, CPG, U, L>
where
    PG: PestGateway,
    CG: CropGateway,
    CPG: crate::pest::gateways::CropPestGateway,
    U: UserLookupGateway,
    L: LoggerPort,
{
    pub fn new(
        user_id: i64,
        user_lookup: &'a U,
        pest_gateway: &'a PG,
        crop_gateway: &'a CG,
        crop_pest_gateway: &'a CPG,
        logger: &'a L,
    ) -> Self {
        Self {
            user_id,
            user_lookup,
            pest_gateway,
            crop_gateway,
            association_sync: CropPestAssociationSync::new(crop_pest_gateway),
            logger,
        }
    }

    pub fn call(
        &self,
        pest_id: i64,
        affected_crops: &[Value],
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
        self.logger
            .info(&format!("🔗 [AI Pest] associate_affected_crops: {affected_crops:?}"));

        let user = self.user_lookup.find(self.user_id);
        let pest = self.pest_gateway.find_by_id(pest_id)?;

        let mut crop_ids = extract_crop_ids(affected_crops);
        self.logger
            .info(&format!("🔗 [AI Pest] Extracted crop IDs: {crop_ids:?}"));

        if crop_ids.is_empty() {
            let names = extract_crop_names(affected_crops);
            crop_ids = self.resolve_crop_ids_from_names(&names, &user)?;
            self.logger.info(&format!(
                "🔗 [AI Pest] Crop IDs after name fallback: {crop_ids:?}"
            ));
        }

        if crop_ids.is_empty() {
            self.logger.warn("⚠️  [AI Pest] No crop IDs resolved from affected_crops");
            return Ok(0);
        }

        let authorized_ids = FilterAssociableCropIds::for_ai_affected_crops(
            &crop_ids,
            &pest,
            &user,
            self.crop_gateway,
        )?;

        let count = self
            .association_sync
            .add_missing(pest_id, &authorized_ids)?;
        self.logger.info(&format!(
            "✅ [AI Pest] Crop association completed: {count} crops associated"
        ));
        Ok(count)
    }

    fn resolve_crop_ids_from_names(
        &self,
        crop_names: &[String],
        user: &crate::shared::user::User,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
        let mut ids = Vec::new();
        for name in crop_names {
            let candidates = self.crop_gateway.list_by_name(name)?;
            if let Some(id) = select_id_for_pest_ai_name_fallback(user, &candidates) {
                self.logger.info(&format!(
                    "✅ [AI Pest] Fallback matched crop by name: {name} -> ID={id}"
                ));
                ids.push(id);
            } else {
                self.logger
                    .warn(&format!("⚠️  [AI Pest] Could not match crop by name: {name}"));
            }
        }
        ids.sort_unstable();
        ids.dedup();
        Ok(ids)
    }
}

#[cfg(test)]
mod interactors_pest_associate_affected_crops_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pest/interactors_pest_associate_affected_crops_interactor_test.rs"));
}
