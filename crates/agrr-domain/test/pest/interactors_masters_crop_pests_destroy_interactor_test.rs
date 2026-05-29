// Tests for `interactors/masters_crop_pests_destroy_interactor.rs` (Ruby parity under test/domain/pest/).

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

    struct PestGw(PestEntity);
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
            Ok(self.0.clone())
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

    fn crop_record(user_id: i64) -> CropRecord {
        CropRecord {
            id: 100,
            is_reference: false,
            user_id: Some(user_id),
            region: None,
            name: Some("トマト".into()),
        }
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

    struct CropPestGw {
        existing: bool,
        delete_ok: bool,
    }

    impl CropPestGateway for CropPestGw {
        fn find_by_crop_id_and_pest_id(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<CropPestLinkEntity>, Box<dyn std::error::Error + Send + Sync>> {
            if self.existing {
                Ok(Some(CropPestLinkEntity::new(1, 100, 7)))
            } else {
                Ok(None)
            }
        }
        fn list_by_pest_id(
            &self,
            _: i64,
        ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }
        fn create(
            &self,
            _: i64,
            _: i64,
        ) -> Result<CropPestLinkEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn delete(&self, _: i64, _: i64) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.delete_ok)
        }
    }

    struct SpyDestroyOutput {
        event: Option<&'static str>,
    }

    impl MastersCropPestsDestroyOutputPort for SpyDestroyOutput {
        fn on_success(&mut self) {
            self.event = Some("success");
        }
        fn on_crop_not_found(&mut self) {
            self.event = Some("crop_not_found");
        }
        fn on_pest_not_found(&mut self) {
            self.event = Some("pest_not_found");
        }
        fn on_not_associated(&mut self) {
            self.event = Some("not_associated");
        }
    }

    // Ruby: test "calls on_not_associated when association is missing"
    #[test]
    fn calls_on_not_associated_when_link_missing() {
        let mut output = SpyDestroyOutput { event: None };
        let user = User::new(1, false);
        let lookup = StubLookup(user);
        let pest_gw = PestGw(pest(1));
        let crop_gw = CropGw(Some(crop_record(1)));
        let crop_pest_gw = CropPestGw {
            existing: false,
            delete_ok: false,
        };
        let mut interactor = MastersCropPestsDestroyInteractor::new(
            &mut output,
            1,
            &lookup,
            &pest_gw,
            &crop_gw,
            &crop_pest_gw,
        );
        interactor.call(100, 7).expect("handled");
        assert_eq!(output.event, Some("not_associated"));
    }

    // Ruby: test "calls on_success when association exists and delete succeeds"
    #[test]
    fn calls_on_success_when_delete_succeeds() {
        let mut output = SpyDestroyOutput { event: None };
        let user = User::new(1, false);
        let lookup = StubLookup(user);
        let pest_gw = PestGw(pest(1));
        let crop_gw = CropGw(Some(crop_record(1)));
        let crop_pest_gw = CropPestGw {
            existing: true,
            delete_ok: true,
        };
        let mut interactor = MastersCropPestsDestroyInteractor::new(
            &mut output,
            1,
            &lookup,
            &pest_gw,
            &crop_gw,
            &crop_pest_gw,
        );
        interactor.call(100, 7).expect("handled");
        assert_eq!(output.event, Some("success"));
    }
