//! Ruby: `Domain::Pest::Interactors::MastersCropPestsIndexInteractor`

use crate::pest::entities::PestEntity;
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
mod tests {
    use super::*;
    use crate::pest::entities::PestEntity;
    use crate::shared::attr::AttrMap;
    use crate::shared::user::User;
    use crate::shared::value_objects::reference_index_list_filter::{
        ReferenceIndexListFilter, ReferenceIndexListMode,
    };

    struct SpyOutput {
        success: Option<Vec<PestEntity>>,
    }

    impl MastersCropPestsIndexOutputPort for SpyOutput {
        fn on_success(&mut self, pests: Vec<PestEntity>) {
            self.success = Some(pests);
        }
    }

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, id: i64) -> User {
            assert_eq!(id, 42);
            self.0
        }
    }

    struct StubGateway {
        accessible: Vec<PestEntity>,
        crop_pests: Vec<PestEntity>,
    }

    impl PestGateway for StubGateway {

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_index_for_filter(
            &self,
            filter: &ReferenceIndexListFilter,
        ) -> Result<Vec<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(filter.mode, ReferenceIndexListMode::ReferenceOrOwned);
            assert_eq!(filter.user_id, 42);
            Ok(self.accessible.clone())
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
        fn list_pests_for_crop_filtered(
            &self,
            crop_id: i64,
            pest_ids: &[i64],
            order: CropPestListOrder,
        ) -> Result<Vec<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(crop_id, 100);
            assert_eq!(pest_ids, &[1, 2]);
            assert_eq!(order, CropPestListOrder::IdAsc);
            Ok(self.crop_pests.clone())
        }
    }

    fn sample_pest(id: i64, user_id: i64) -> PestEntity {
        PestEntity {
            id,
            user_id: Some(user_id),
            name: if id == 1 { "A".into() } else { "B".into() },
            name_scientific: None,
            family: None,
            order: None,
            description: None,
            occurrence_season: None,
            region: None,
            is_reference: false,
            created_at: None,
            updated_at: None,
        }
    }

    // Ruby: test "on_success filters crop pests by selectable list policy"
    #[test]
    fn on_success_filters_crop_pests_by_selectable_list_policy() {
        let accessible = vec![sample_pest(1, 42), sample_pest(2, 42)];
        let crop_pests = vec![accessible[0].clone()];
        let gateway = StubGateway {
            accessible: accessible.clone(),
            crop_pests: crop_pests.clone(),
        };
        let mut output = SpyOutput { success: None };
        let lookup = StubLookup(User::new(42, false));
        let mut interactor =
            MastersCropPestsIndexInteractor::new(&mut output, 42, &lookup, &gateway);

        interactor.call(100).unwrap();

        assert_eq!(output.success.as_ref(), Some(&crop_pests));
    }
}
