    use crate::organization::gateways::{
        PersonalOrganizationGateway, PersonalOrganizationUserRow,
    };
    use crate::shared::gateways::UserOrganizationScopeGateway;
    use crate::shared::org_scope::{
        member_organization_ids, organization_member_access, resolve_creation_organization_id,
    };

    struct TestScopeGateway {
        result: Result<Vec<i64>, &'static str>,
    }

    impl UserOrganizationScopeGateway for TestScopeGateway {
        fn organization_ids_for_user(
            &self,
            _user_id: i64,
        ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
            self.result
                .clone()
                .map_err(|msg| -> Box<dyn std::error::Error + Send + Sync> {
                    msg.into()
                })
        }
    }

    struct TestPersonalOrgGateway {
        ensure_result: Result<i64, &'static str>,
    }

    impl PersonalOrganizationGateway for TestPersonalOrgGateway {
        fn ensure_personal_organization(
            &self,
            _user_id: i64,
            _email: &str,
            _name: &str,
        ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
            self.ensure_result
                .clone()
                .map_err(|msg| -> Box<dyn std::error::Error + Send + Sync> {
                    msg.into()
                })
        }

        fn list_users_needing_personal_organization(
            &self,
        ) -> Result<Vec<PersonalOrganizationUserRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }

        fn list_users_with_unassigned_organization_rows(
            &self,
        ) -> Result<Vec<PersonalOrganizationUserRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
    }

    #[test]
    fn resolve_creation_organization_id_returns_first_membership() {
        let scope = TestScopeGateway {
            result: Ok(vec![42, 99]),
        };
        let personal = TestPersonalOrgGateway {
            ensure_result: Err("should not ensure when memberships exist"),
        };
        let out = resolve_creation_organization_id(&scope, &personal, 7).expect("ok");
        assert_eq!(out, 42);
    }

    #[test]
    fn resolve_creation_organization_id_ensures_personal_when_no_memberships() {
        let scope = TestScopeGateway {
            result: Ok(vec![]),
        };
        let personal = TestPersonalOrgGateway {
            ensure_result: Ok(1001),
        };
        let out = resolve_creation_organization_id(&scope, &personal, 7).expect("ok");
        assert_eq!(out, 1001);
    }

    #[test]
    fn resolve_creation_organization_id_propagates_scope_error() {
        let scope = TestScopeGateway {
            result: Err("scope failed"),
        };
        let personal = TestPersonalOrgGateway {
            ensure_result: Ok(1),
        };
        let err = resolve_creation_organization_id(&scope, &personal, 7).expect_err("err");
        assert_eq!(err.to_string(), "scope failed");
    }

    #[test]
    fn member_organization_ids_delegates_to_gateway() {
        let scope = TestScopeGateway {
            result: Ok(vec![1, 2]),
        };
        let out = member_organization_ids(&scope, 99).expect("ok");
        assert_eq!(out, vec![1, 2]);
    }

    #[test]
    fn organization_member_access_denies_reference_records_even_when_id_matches() {
        let ids = [10, 20];
        assert!(!organization_member_access(&ids, true, Some(10)));
    }

    #[test]
    fn organization_member_access_requires_matching_org_id() {
        let ids = [10, 20];
        assert!(organization_member_access(&ids, false, Some(20)));
        assert!(!organization_member_access(&ids, false, Some(99)));
        assert!(!organization_member_access(&ids, false, None));
    }
