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
mod tests {
    use super::*;
    use crate::pest::entities::{CropPestLinkEntity, PestEntity, PestEntityAttrs};
    use crate::pest::gateways::CropRecord;
    use crate::shared::exceptions::RecordNotFoundError;

    fn crop(id: i64) -> CropRecord {
        CropRecord {
            id,
            is_reference: false,
            user_id: Some(2),
            region: None,
            name: Some("Tomato".into()),
        }
    }

    fn pest_entity() -> PestEntity {
        PestEntity::new(PestEntityAttrs {
            id: Some(3),
            user_id: Some(2),
            name: "Aphid".into(),
            is_reference: false,
            ..Default::default()
        })
        .expect("valid")
    }

    struct CropGw(Option<CropRecord>);
    impl CropGateway for CropGw {
    
    fn find_by_id(
            &self,
            _: i64,
        ) -> Result<Option<CropRecord>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.0.clone())
        }
        fn list_by_name(
            &self,
            _: &str,
        ) -> Result<Vec<CropRecord>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }
    }

    struct PestGw {
        entity: Option<PestEntity>,
    }

    impl PestGateway for PestGw {


        fn list_pests_for_crop_filtered(
            &self,
            _: i64,
            _: &[i64],
            _: crate::pest::gateways::CropPestListOrder,
        ) -> Result<Vec<crate::pest::entities::PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            match &self.entity {
                Some(e) => Ok(e.clone()),
                None => Err(Box::new(RecordNotFoundError)),
            }
        }
        fn create_for_user(
            &self,
            _: &crate::shared::user::User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &crate::shared::user::User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn find_pest_show_detail(
            &self,
            _: i64,
        ) -> Result<crate::pest::dtos::PestShowDetail, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<crate::pest::dtos::PestDeleteUsage, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &crate::shared::user::User,
            _: i64,
            _: i64,
            _: &dyn crate::shared::ports::TranslatorPort,
        ) -> Result<
            crate::pest::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn find_by_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }
}

