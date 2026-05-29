// Tests for `interactors/masters_crop_pests_create_interactor.rs` (Ruby parity under test/domain/pest/).

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
            Ok(CropPestLinkEntity::new(1, 100, 7))
        }
        fn delete(&self, _: i64, _: i64) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
            Ok(true)
        }
    }

    struct SpyCreateOutput {
        event: Option<&'static str>,
        pair: Option<(i64, i64)>,
    }

    impl MastersCropPestsCreateOutputPort for SpyCreateOutput {
        fn on_success(&mut self, crop_id: i64, pest_id: i64) {
            self.event = Some("success");
            self.pair = Some((crop_id, pest_id));
        }
        fn on_pest_id_missing(&mut self) {
            self.event = Some("pest_id_missing");
        }
        fn on_pest_not_found(&mut self) {
            self.event = Some("pest_not_found");
        }
        fn on_forbidden(&mut self) {
            self.event = Some("forbidden");
        }
        fn on_already_associated(&mut self) {
            self.event = Some("already_associated");
        }
    }

    // Ruby: test "calls on_pest_not_found when find_by_id raises RecordNotFound"
    #[test]
    fn calls_on_pest_not_found_when_pest_missing() {
        let pest_gateway = PestGw {
            entity: Err(false),
        };
        let crop_gw = CropGw(None);
        let crop_pest_gw = CropPestGw { existing: false };
        let mut output = SpyCreateOutput {
            event: None,
            pair: None,
        };
        let user = User::new(1, false);
        let lookup = StubLookup(user);
        let mut interactor = MastersCropPestsCreateInteractor::new(
            &mut output,
            1,
            &lookup,
            &pest_gateway,
            &crop_gw,
            &crop_pest_gw,
        );
        interactor
            .call(MastersCropPestsCreateInput::new(100, Some(7)))
            .expect("handled");
        assert_eq!(output.event, Some("pest_not_found"));
    }

    // Ruby: test "calls on_success when pest is found, selectable, and association is created"
    #[test]
    fn calls_on_success_when_association_created() {
        let pest_gateway = PestGw {
            entity: Ok(pest(1)),
        };
        let crop_gw = CropGw(Some(crop_record(1)));
        let crop_pest_gw = CropPestGw { existing: false };
        let mut output = SpyCreateOutput {
            event: None,
            pair: None,
        };
        let user = User::new(1, false);
        let lookup = StubLookup(user);
        let mut interactor = MastersCropPestsCreateInteractor::new(
            &mut output,
            1,
            &lookup,
            &pest_gateway,
            &crop_gw,
            &crop_pest_gw,
        );
        interactor
            .call(MastersCropPestsCreateInput::new(100, Some(7)))
            .expect("handled");
        assert_eq!(output.event, Some("success"));
        assert_eq!(output.pair, Some((100, 7)));
    }

    // Ruby: test "calls on_already_associated when association already exists"
    #[test]
    fn calls_on_already_associated_when_link_exists() {
        let pest_gateway = PestGw {
            entity: Ok(pest(1)),
        };
        let crop_gw = CropGw(Some(crop_record(1)));
        let crop_pest_gw = CropPestGw { existing: true };
        let mut output = SpyCreateOutput {
            event: None,
            pair: None,
        };
        let user = User::new(1, false);
        let lookup = StubLookup(user);
        let mut interactor = MastersCropPestsCreateInteractor::new(
            &mut output,
            1,
            &lookup,
            &pest_gateway,
            &crop_gw,
            &crop_pest_gw,
        );
        interactor
            .call(MastersCropPestsCreateInput::new(100, Some(7)))
            .expect("handled");
        assert_eq!(output.event, Some("already_associated"));
    }
