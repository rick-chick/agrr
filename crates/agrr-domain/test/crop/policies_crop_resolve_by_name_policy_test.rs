// Tests for `policies/crop_resolve_by_name_policy.rs` (Ruby parity under test/domain/crop/).


    fn crop(id: i64, is_reference: bool, user_id: Option<i64>) -> CropEntity {
        CropEntity {
            id,
            user_id,
            name: format!("crop-{id}"),
            variety: None,
            is_reference,
            area_per_unit: None,
            revenue_per_area: None,
            region: None,
            groups: vec![],
            created_at: None,
            updated_at: None,
        }
    }

    // Ruby: test "returns nil when candidates empty"
    #[test]
    fn returns_nil_when_candidates_empty() {
        let user = User::new(1, false);
        assert_eq!(select_id_for_pest_ai_name_fallback(&user, &[]), None);
    }

    // Ruby: test "prefers reference crop"
    #[test]
    fn prefers_reference_crop() {
        let user = User::new(1, false);
        let candidates = vec![crop(2, false, Some(1)), crop(1, true, None)];
        assert_eq!(
            select_id_for_pest_ai_name_fallback(&user, &candidates),
            Some(1)
        );
    }

    // Ruby: test "selects editable owned crop when no reference"
    #[test]
    fn selects_editable_owned_crop() {
        let user = User::new(1, false);
        let candidates = vec![crop(3, false, Some(99)), crop(2, false, Some(1))];
        assert_eq!(
            select_id_for_pest_ai_name_fallback(&user, &candidates),
            Some(2)
        );
    }
