// Tests for `value_objects/reference_index_list_filter.rs` (Ruby parity under test/domain/shared/).



    struct EmptyScopeGateway;
    impl crate::shared::gateways::UserOrganizationScopeGateway for EmptyScopeGateway {
        fn organization_ids_for_user(
            &self,
            _: i64,
        ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }
    }
    #[test]
    fn equality_and_hash() {
        use std::hash::{Hash, Hasher};
        let a = ReferenceIndexListFilter::new(ReferenceIndexListMode::ReferenceOrOwned, 1, vec![]);
        let b = ReferenceIndexListFilter::new(ReferenceIndexListMode::ReferenceOrOwned, 1, vec![]);
        assert_eq!(a, b);
        let mut ha = std::collections::hash_map::DefaultHasher::new();
        let mut hb = std::collections::hash_map::DefaultHasher::new();
        a.hash(&mut ha);
        b.hash(&mut hb);
        assert_eq!(ha.finish(), hb.finish());
    }

    #[test]
    fn rejects_invalid_mode() {
        assert!(ReferenceIndexListFilter::try_new("bogus", 1, vec![]).is_err());
    }
