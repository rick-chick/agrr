//! Ruby: `Domain::Pesticide::Interactors::MastersCropPesticidesIndexInteractor`

use crate::pesticide::gateways::{CropGateway, PesticideGateway};
use crate::pesticide::policies::assert_edit_allowed_for_masters;
use crate::pesticide::ports::MastersCropPesticidesIndexOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::pesticide_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub struct MastersCropPesticidesIndexInteractor<'a, PG, CG, O, U> {
    output_port: &'a mut O,
    user_id: i64,
    user_lookup: &'a U,
    pesticide_gateway: &'a PG,
    crop_gateway: &'a CG,
}

impl<'a, PG, CG, O, U> MastersCropPesticidesIndexInteractor<'a, PG, CG, O, U>
where
    PG: PesticideGateway,
    CG: CropGateway,
    O: MastersCropPesticidesIndexOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        user_lookup: &'a U,
        pesticide_gateway: &'a PG,
        crop_gateway: &'a CG,
    ) -> Self {
        Self {
            output_port,
            user_id,
            user_lookup,
            pesticide_gateway,
            crop_gateway,
        }
    }

    pub fn call(
        &mut self,
        crop_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);

        let crop_entity = match self.crop_gateway.find_by_id(crop_id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some()
                    || err.downcast_ref::<PolicyPermissionDenied>().is_some()
                {
                    self.output_port.on_not_found();
                    return Ok(());
                }
                return Err(err);
            }
        };

        if assert_edit_allowed_for_masters(user, &crop_entity).is_err() {
            self.output_port.on_not_found();
            return Ok(());
        }

        let filter = pesticide_policy::masters_crop_pesticides_index_filter(&user);
        let pesticides = self
            .pesticide_gateway
            .list_by_crop_id_for_filter(crop_entity.id, &filter)?;
        self.output_port.on_success(pesticides);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pesticide::entities::{PesticideEntity, PesticideEntityAttrs};
    use crate::pesticide::gateways::CropRecord;
    use crate::shared::user::User;
    use crate::shared::value_objects::reference_index_list_filter::{
        ReferenceIndexListFilter, ReferenceIndexListMode,
    };

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct SpyOutput {
        success: Option<Vec<PesticideEntity>>,
        not_found: bool,
    }

    impl MastersCropPesticidesIndexOutputPort for SpyOutput {
        fn on_success(&mut self, pesticides: Vec<PesticideEntity>) {
            self.success = Some(pesticides);
        }
        fn on_not_found(&mut self) {
            self.not_found = true;
        }
    }

    struct TestCropGateway {
        crop: CropLookupResult,
    }

    enum CropLookupResult {
        Found(CropRecord),
        Missing,
    }

    impl CropGateway for TestCropGateway {
    
    fn find_by_id(
            &self,
            _: i64,
        ) -> Result<CropRecord, Box<dyn std::error::Error + Send + Sync>> {
            match self.crop {
                CropLookupResult::Found(c) => Ok(c),
                CropLookupResult::Missing => Err(Box::new(RecordNotFoundError)),
            }
        }
    }

    struct TestPesticideGateway {
        pesticides: Vec<PesticideEntity>,
        expect_crop_id: i64,
        expect_filter_mode: ReferenceIndexListMode,
        expect_user_id: i64,
    }

    impl PesticideGateway for TestPesticideGateway {

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_index_for_filter(
            &self,
            _: &ReferenceIndexListFilter,
        ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_pesticide_show_detail(
            &self,
            _: i64,
        ) -> Result<
            crate::pesticide::gateways::PesticideShowDetailGatewayDto,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }

        fn create_for_user(
            &self,
            _: &User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn crate::shared::ports::TranslatorPort,
        ) -> Result<
            crate::pesticide::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }

        fn list_by_crop_id_for_filter(
            &self,
            crop_id: i64,
            filter: &ReferenceIndexListFilter,
        ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(crop_id, self.expect_crop_id);
            assert_eq!(filter.mode, self.expect_filter_mode);
            assert_eq!(filter.user_id, self.expect_user_id);
            Ok(self.pesticides.clone())
        }
    }

    fn sample_pesticide(id: i64) -> PesticideEntity {
        PesticideEntity::new(PesticideEntityAttrs {
            id,
            user_id: Some(1),
            name: "P".into(),
            active_ingredient: None,
            description: None,
            crop_id: Some(5),
            pest_id: None,
            region: None,
            is_reference: false,
            created_at: "2026-01-01T00:00:00Z".into(),
            updated_at: "2026-01-01T00:00:00Z".into(),
        })
        .expect("valid")
    }

    // Ruby: test "on_success lists pesticides for authorized crop"
    #[test]
    fn on_success_lists_pesticides_for_authorized_crop() {
        let pesticides = vec![sample_pesticide(1)];
        let crop_gateway = TestCropGateway {
            crop: CropLookupResult::Found(CropRecord {
                id: 5,
                is_reference: false,
                user_id: Some(1),
            }),
        };
        let pesticide_gateway = TestPesticideGateway {
            pesticides: pesticides.clone(),
            expect_crop_id: 5,
            expect_filter_mode: ReferenceIndexListMode::ReferenceOrOwned,
            expect_user_id: 1,
        };
        let mut output = SpyOutput {
            success: None,
            not_found: false,
        };
        let lookup = StubLookup(User::new(1, false));
        let mut interactor = MastersCropPesticidesIndexInteractor::new(
            &mut output,
            1,
            &lookup,
            &pesticide_gateway,
            &crop_gateway,
        );
        interactor.call(5).expect("handled");
        assert_eq!(output.success, Some(pesticides));
    }

    // Ruby: test "on_not_found when crop is reference only"
    #[test]
    fn on_not_found_when_crop_is_reference_only() {
        let crop_gateway = TestCropGateway {
            crop: CropLookupResult::Found(CropRecord {
                id: 5,
                is_reference: true,
                user_id: None,
            }),
        };
        struct NeverCalledPesticideGateway;
        impl PesticideGateway for NeverCalledPesticideGateway {
            fn find_by_id(
                &self,
                _: i64,
            ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }
            fn list_index_for_filter(
                &self,
                _: &ReferenceIndexListFilter,
            ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }
            fn find_pesticide_show_detail(
                &self,
                _: i64,
            ) -> Result<
                crate::pesticide::gateways::PesticideShowDetailGatewayDto,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }
            fn create_for_user(
                &self,
                _: &User,
                _: crate::shared::attr::AttrMap,
            ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }
            fn update_for_user(
                &self,
                _: &User,
                _: i64,
                _: crate::shared::attr::AttrMap,
            ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }
            fn soft_delete_with_undo(
                &self,
                _: &User,
                _: i64,
                _: i64,
                _: &dyn crate::shared::ports::TranslatorPort,
            ) -> Result<
                crate::pesticide::gateways::SoftDeleteWithUndoOutcome,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }
            fn list_by_crop_id_for_filter(
                &self,
                _: i64,
                _: &ReferenceIndexListFilter,
            ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>> {
                panic!("should not list when crop access denied")
            }
        }
        let mut output = SpyOutput {
            success: None,
            not_found: false,
        };
        let lookup = StubLookup(User::new(1, false));
        let mut interactor = MastersCropPesticidesIndexInteractor::new(
            &mut output,
            1,
            &lookup,
            &NeverCalledPesticideGateway,
            &crop_gateway,
        );
        interactor.call(5).expect("handled");
        assert!(output.not_found);
        assert!(output.success.is_none());
    }

    // Ruby: test "on_not_found when crop missing"
    #[test]
    fn on_not_found_when_crop_missing() {
        let crop_gateway = TestCropGateway {
            crop: CropLookupResult::Missing,
        };
        struct NeverCalledPesticideGateway;
        impl PesticideGateway for NeverCalledPesticideGateway {
            fn find_by_id(
                &self,
                _: i64,
            ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }
            fn list_index_for_filter(
                &self,
                _: &ReferenceIndexListFilter,
            ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }
            fn find_pesticide_show_detail(
                &self,
                _: i64,
            ) -> Result<
                crate::pesticide::gateways::PesticideShowDetailGatewayDto,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }
            fn create_for_user(
                &self,
                _: &User,
                _: crate::shared::attr::AttrMap,
            ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }
            fn update_for_user(
                &self,
                _: &User,
                _: i64,
                _: crate::shared::attr::AttrMap,
            ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }
            fn soft_delete_with_undo(
                &self,
                _: &User,
                _: i64,
                _: i64,
                _: &dyn crate::shared::ports::TranslatorPort,
            ) -> Result<
                crate::pesticide::gateways::SoftDeleteWithUndoOutcome,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }
            fn list_by_crop_id_for_filter(
                &self,
                _: i64,
                _: &ReferenceIndexListFilter,
            ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>> {
                panic!("should not list when crop missing")
            }
        }
        let mut output = SpyOutput {
            success: None,
            not_found: false,
        };
        let lookup = StubLookup(User::new(1, false));
        let mut interactor = MastersCropPesticidesIndexInteractor::new(
            &mut output,
            1,
            &lookup,
            &NeverCalledPesticideGateway,
            &crop_gateway,
        );
        interactor.call(99).expect("handled");
        assert!(output.not_found);
    }
}
