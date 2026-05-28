use crate::pest::dtos::PestCropAssociationSyncResult;
use crate::pest::gateways::CropPestGateway;

/// Ruby: `Domain::Pest::Services::CropPestAssociationSync`
pub struct CropPestAssociationSync<'a, G> {
    crop_pest_gateway: &'a G,
}

impl<'a, G: CropPestGateway> CropPestAssociationSync<'a, G> {
    pub fn new(crop_pest_gateway: &'a G) -> Self {
        Self { crop_pest_gateway }
    }

    pub fn add_missing(
        &self,
        pest_id: i64,
        crop_ids: &[i64],
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
        let mut added = 0i64;
        for &crop_id in crop_ids {
            let exists = self
                .crop_pest_gateway
                .find_by_crop_id_and_pest_id(crop_id, pest_id)?
                .is_some();
            if !exists {
                self.crop_pest_gateway.create(crop_id, pest_id)?;
                added += 1;
            }
        }
        Ok(added)
    }

    pub fn replace_all(
        &self,
        pest_id: i64,
        crop_ids: &[i64],
    ) -> Result<PestCropAssociationSyncResult, Box<dyn std::error::Error + Send + Sync>> {
        let mut new_ids: Vec<i64> = crop_ids.to_vec();
        new_ids.sort_unstable();
        new_ids.dedup();

        let current_ids = self.crop_pest_gateway.list_by_pest_id(pest_id)?;
        let mut removed_count = 0i64;
        for crop_id in current_ids.iter().copied() {
            if !new_ids.contains(&crop_id) {
                if self.crop_pest_gateway.delete(crop_id, pest_id)? {
                    removed_count += 1;
                }
            }
        }

        let to_add: Vec<i64> = new_ids
            .iter()
            .copied()
            .filter(|id| !current_ids.contains(id))
            .collect();
        let added_count = self.add_missing(pest_id, &to_add)?;
        Ok(PestCropAssociationSyncResult::new(added_count, removed_count))
    }
}
