use crate::pest::entities::PestEntity;
use crate::pest::gateways::{CropGateway, CropRecord};
use crate::shared::policies::crop_policy;
use crate::shared::user::User;

type LinkableFn = fn(
    Option<&User>,
    bool,
    Option<i64>,
    Option<&str>,
    bool,
    Option<i64>,
    Option<&str>,
) -> bool;

fn pest_update_linkable(
    user: Option<&User>,
    crop_is_reference: bool,
    crop_user_id: Option<i64>,
    crop_region: Option<&str>,
    pest_is_reference: bool,
    pest_user_id: Option<i64>,
    pest_region: Option<&str>,
) -> bool {
    crop_policy::crop_associable_with_pest(
        user.expect("user required for pest update linking"),
        crop_is_reference,
        crop_user_id,
        crop_region,
        pest_is_reference,
        pest_user_id,
        pest_region,
    )
}

/// Ruby: `Domain::Pest::Services::FilterAssociableCropIds`
pub struct FilterAssociableCropIds;

impl FilterAssociableCropIds {
    pub fn for_pest_update<G: CropGateway>(
        crop_ids: &[i64],
        pest: &PestEntity,
        user: &User,
        crop_gateway: &G,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
        Self::filter(
            crop_ids,
            user,
            crop_gateway,
            pest.reference(),
            pest.user_id,
            pest.region.as_deref(),
            pest_update_linkable,
        )
    }

    pub fn for_ai_affected_crops<G: CropGateway>(
        crop_ids: &[i64],
        pest: &PestEntity,
        user: &User,
        crop_gateway: &G,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
        Self::filter(
            crop_ids,
            user,
            crop_gateway,
            pest.reference(),
            pest.user_id,
            pest.region.as_deref(),
            crop_policy::ai_affected_crop_linkable,
        )
    }

    fn filter<G: CropGateway>(
        crop_ids: &[i64],
        user: &User,
        crop_gateway: &G,
        pest_is_reference: bool,
        pest_user_id: Option<i64>,
        pest_region: Option<&str>,
        linkable: LinkableFn,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
        let mut out = Vec::new();
        for &crop_id in crop_ids {
            match crop_gateway.find_by_id(crop_id)? {
                Some(crop) => {
                    if Self::crop_linkable(
                        user,
                        &crop,
                        pest_is_reference,
                        pest_user_id,
                        pest_region,
                        linkable,
                    ) {
                        out.push(crop.id);
                    }
                }
                None => {}
            }
        }
        out.sort_unstable();
        out.dedup();
        Ok(out)
    }

    fn crop_linkable(
        user: &User,
        crop: &CropRecord,
        pest_is_reference: bool,
        pest_user_id: Option<i64>,
        pest_region: Option<&str>,
        linkable: LinkableFn,
    ) -> bool {
        linkable(
            Some(user),
            crop.is_reference,
            crop.user_id,
            crop.region.as_deref(),
            pest_is_reference,
            pest_user_id,
            pest_region,
        )
    }
}
