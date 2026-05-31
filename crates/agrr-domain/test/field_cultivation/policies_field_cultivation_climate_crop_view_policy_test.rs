// Tests for `policies/field_cultivation_climate_crop_view_policy.rs` (Ruby parity under test/domain/field_cultivation/).

    use crate::field_cultivation::dtos::ClimateCropEntity;

    fn crop(is_reference: bool, user_id: Option<i64>) -> ClimateCropEntity {
        ClimateCropEntity {
            id: 1,
            name: "crop".into(),
            variety: None,
            area_per_unit: None,
            revenue_per_area: None,
            groups: serde_json::json!([]),
            is_reference,
            user_id,
            crop_stages: vec![],
        }
    }

    #[test]
    fn public_plan_allows_reference_crop_only() {
        assert!(view_allowed(None, &crop(true, None), true));
        assert!(!view_allowed(None, &crop(false, Some(1)), true));
    }

    #[test]
    fn private_plan_uses_crop_policy() {
        let user = User::new(5, false);
        assert!(view_allowed(Some(&user), &crop(false, Some(5)), false));
        assert!(!view_allowed(Some(&user), &crop(false, Some(99)), false));
    }
