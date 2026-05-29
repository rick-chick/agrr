// Tests for `interactors/pest_associate_affected_crops_interactor.rs` (Ruby parity under test/domain/pest/).

    use crate::pest::entities::{PestEntity, PestEntityAttrs};
    use crate::pest::gateways::{CropGateway, CropPestGateway, CropRecord};
    use crate::shared::user::User;
    use serde_json::json;
    use std::collections::HashMap;
    use std::sync::Mutex;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct NoopLogger;
    impl LoggerPort for NoopLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
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

    fn pest_entity() -> PestEntity {
        PestEntity::new(PestEntityAttrs {
            id: Some(10),
            user_id: Some(1),
            name: "p".into(),
            is_reference: false,
            ..Default::default()
        })
        .expect("valid")
    }

    struct CropGw {
        by_id: HashMap<i64, CropRecord>,
        by_name: Vec<CropRecord>,
    }

    impl CropGateway for CropGw {
        fn find_by_id(
            &self,
            id: i64,
        ) -> Result<Option<CropRecord>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.by_id.get(&id).cloned())
        }
        fn list_by_name(
            &self,
            name: &str,
        ) -> Result<Vec<CropRecord>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self
                .by_name
                .iter()
                .filter(|c| c.name.as_deref() == Some(name))
                .cloned()
                .collect())
        }
    }

    struct CropPestSyncGw {
        links: Mutex<HashMap<(i64, i64), crate::pest::entities::CropPestLinkEntity>>,
    }

    impl CropPestGateway for CropPestSyncGw {
        fn find_by_crop_id_and_pest_id(
            &self,
            crop_id: i64,
            pest_id: i64,
        ) -> Result<
            Option<crate::pest::entities::CropPestLinkEntity>,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            Ok(self
                .links
                .lock()
                .expect("lock")
                .get(&(crop_id, pest_id))
                .cloned())
        }
        fn list_by_pest_id(
            &self,
            _: i64,
        ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }
        fn create(
            &self,
            crop_id: i64,
            pest_id: i64,
        ) -> Result<crate::pest::entities::CropPestLinkEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            let link = crate::pest::entities::CropPestLinkEntity::new(1, crop_id, pest_id);
            self.links
                .lock()
                .expect("lock")
                .insert((crop_id, pest_id), link.clone());
            Ok(link)
        }
        fn delete(&self, _: i64, _: i64) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
            Ok(false)
        }
    }

    // Ruby: test "persists only authorized crop ids from payload"
    #[test]
    fn persists_only_authorized_crop_ids_from_payload() {
        let mut by_id = HashMap::new();
        by_id.insert(
            2,
            CropRecord {
                id: 2,
                is_reference: false,
                user_id: Some(1),
                region: None,
                name: Some("Mine".into()),
            },
        );
        by_id.insert(
            3,
            CropRecord {
                id: 3,
                is_reference: false,
                user_id: Some(99),
                region: None,
                name: Some("Other".into()),
            },
        );
        let crop_pest = CropPestSyncGw {
            links: Mutex::new(HashMap::new()),
        };
        let pest_gw = PestGw(pest_entity());
        let crop_gw = CropGw {
            by_id,
            by_name: vec![],
        };
        let user = User::new(1, false);
        let lookup = StubLookup(user);
        let interactor = PestAssociateAffectedCropsInteractor::new(
            1,
            &lookup,
            &pest_gw,
            &crop_gw,
            &crop_pest,
            &NoopLogger,
        );
        let count = interactor
            .call(
                10,
                &[json!({"crop_id": 2}), json!({"crop_id": 3})],
            )
            .expect("ok");
        assert_eq!(count, 1);
        assert!(crop_pest
            .links
            .lock()
            .expect("lock")
            .contains_key(&(2, 10)));
    }

    // Ruby: test "resolves crop id by name when ids absent"
    #[test]
    fn resolves_crop_id_by_name_when_ids_absent() {
        let crop = CropRecord {
            id: 5,
            is_reference: true,
            user_id: None,
            region: Some("jp".into()),
            name: Some("RefTomato".into()),
        };
        let mut by_id = HashMap::new();
        by_id.insert(5, crop.clone());
        let crop_pest = CropPestSyncGw {
            links: Mutex::new(HashMap::new()),
        };
        let pest_gw = PestGw(pest_entity());
        let crop_gw = CropGw {
            by_id,
            by_name: vec![crop],
        };
        let user = User::new(1, false);
        let lookup = StubLookup(user);
        let interactor = PestAssociateAffectedCropsInteractor::new(
            1,
            &lookup,
            &pest_gw,
            &crop_gw,
            &crop_pest,
            &NoopLogger,
        );
        let count = interactor
            .call(10, &[json!({"crop_name": "RefTomato"})])
            .expect("ok");
        assert_eq!(count, 1);
    }
