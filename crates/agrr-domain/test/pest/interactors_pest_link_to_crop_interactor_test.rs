// Tests for `interactors/pest_link_to_crop_interactor.rs` (Ruby parity under test/domain/pest/).

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

    struct CropPestGw {
        existing: Option<CropPestLinkEntity>,
    }

    impl CropPestGateway for CropPestGw {
        fn find_by_crop_id_and_pest_id(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<CropPestLinkEntity>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.existing.clone())
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
            Ok(CropPestLinkEntity::new(9, 1, 3))
        }
        fn delete(&self, _: i64, _: i64) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
            Ok(true)
        }
    }

    // Ruby: test "returns :linked when crop and pest exist and association is new"
    #[test]
    fn returns_linked_when_association_is_new() {
        let pest_gw = PestGw {
            entity: Some(pest_entity()),
        };
        let crop_pest_gw = CropPestGw { existing: None };
        let crop_gw = CropGw(Some(crop(1)));
        let interactor =
            PestLinkToCropInteractor::new(&pest_gw, &crop_pest_gw, &crop_gw);
        assert_eq!(
            interactor.call(1, 3).expect("ok"),
            PestLinkToCropOutcome::Linked
        );
    }

    // Ruby: test "returns :already_linked when association exists"
    #[test]
    fn returns_already_linked_when_association_exists() {
        let pest_gw = PestGw {
            entity: Some(pest_entity()),
        };
        let crop_pest_gw = CropPestGw {
            existing: Some(CropPestLinkEntity::new(9, 1, 3)),
        };
        let crop_gw = CropGw(Some(crop(1)));
        let interactor =
            PestLinkToCropInteractor::new(&pest_gw, &crop_pest_gw, &crop_gw);
        assert_eq!(
            interactor.call(1, 3).expect("ok"),
            PestLinkToCropOutcome::AlreadyLinked
        );
    }
