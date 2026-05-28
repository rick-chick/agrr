//! Ruby: `Domain::Pest::Interactors::MastersCropPestsCreateInteractor`

use crate::pest::dtos::MastersCropPestsCreateInput;
use crate::pest::gateways::{CropGateway, CropPestGateway, PestGateway};
use crate::pest::ports::MastersCropPestsCreateOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_nested_pests_access;
use crate::shared::policies::crop_policy;
use crate::shared::policies::pest_policy;

pub struct MastersCropPestsCreateInteractor<'a, O, PG, CG, CPG, U> {
    output_port: &'a mut O,
    user_id: i64,
    user_lookup: &'a U,
    pest_gateway: &'a PG,
    crop_gateway: &'a CG,
    crop_pest_gateway: &'a CPG,
}

impl<'a, O, PG, CG, CPG, U> MastersCropPestsCreateInteractor<'a, O, PG, CG, CPG, U>
where
    O: MastersCropPestsCreateOutputPort,
    PG: PestGateway,
    CG: CropGateway,
    CPG: CropPestGateway,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        user_lookup: &'a U,
        pest_gateway: &'a PG,
        crop_gateway: &'a CG,
        crop_pest_gateway: &'a CPG,
    ) -> Self {
        Self {
            output_port,
            user_id,
            user_lookup,
            pest_gateway,
            crop_gateway,
            crop_pest_gateway,
        }
    }

    pub fn call(
        &mut self,
        input: MastersCropPestsCreateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let Some(pest_id) = input.pest_id_raw else {
            self.output_port.on_pest_id_missing();
            return Ok(());
        };

        let pest_entity = match self.pest_gateway.find_by_id(pest_id) {
            Ok(entity) => entity,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_pest_not_found();
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        let user = self.user_lookup.find(self.user_id);

        if !pest_policy::selectable_for_user(
            &user,
            pest_entity.reference(),
            pest_entity.user_id,
        ) {
            self.output_port.on_forbidden();
            return Ok(());
        }

        let crop = match self.crop_gateway.find_by_id(input.crop_id)? {
            Some(crop) => crop,
            None => {
                self.output_port.on_pest_not_found();
                return Ok(());
            }
        };

        if crop_nested_pests_access::assert_allowed(&user, &crop).is_err() {
            self.output_port.on_forbidden();
            return Ok(());
        }

        if !crop_policy::crop_associable_with_pest(
            &user,
            crop.is_reference,
            crop.user_id,
            crop.region.as_deref(),
            pest_entity.reference(),
            pest_entity.user_id,
            pest_entity.region.as_deref(),
        ) {
            self.output_port.on_forbidden();
            return Ok(());
        }

        if self
            .crop_pest_gateway
            .find_by_crop_id_and_pest_id(input.crop_id, pest_entity.id)?
            .is_some()
        {
            self.output_port.on_already_associated();
            return Ok(());
        }

        self.crop_pest_gateway
            .create(input.crop_id, pest_entity.id)?;
        self.output_port
            .on_success(input.crop_id, pest_entity.id);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pest::entities::{CropPestLinkEntity, PestEntity, PestEntityAttrs};
    use crate::pest::gateways::CropRecord;
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    fn pest(user_id: i64) -> PestEntity {
        PestEntity::new(PestEntityAttrs {
            id: Some(7),
            user_id: Some(user_id),
            name: "アブラムシ".into(),
            is_reference: false,
            ..Default::default()
        })
        .expect("valid")
    }

    struct PestGw {
        entity: Result<PestEntity, bool>,
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
                Ok(e) => Ok(e.clone()),
                Err(_) => Err(Box::new(RecordNotFoundError)),
            }
        }
        fn create_for_user(
            &self,
            _: &User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &User,
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
            _: &User,
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

