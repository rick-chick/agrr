// Tests for `policies/crop_task_template_sync_policy.rs` (Ruby parity under test/domain/agricultural_task/).

    use crate::agricultural_task::entities::AgriculturalTaskEntityAttrs;
    use crate::shared::attr::AttrValue;

    // Ruby: test "crop_associate_region_filter は region があるときだけ値を返す"
    #[test]
    fn crop_associate_region_filter_returns_region_when_present() {
        assert_eq!(
            CropTaskTemplateSyncPolicy::crop_associate_region_filter(Some("jp")).as_deref(),
            Some("jp")
        );
        assert!(CropTaskTemplateSyncPolicy::crop_associate_region_filter(None).is_none());
        assert!(CropTaskTemplateSyncPolicy::crop_associate_region_filter(Some("")).is_none());
    }

    // Ruby: test "allowed_crop_ids intersects selected with scope"
    #[test]
    fn allowed_crop_ids_intersects_selected_with_scope() {
        let allowed = CropTaskTemplateSyncPolicy::allowed_crop_ids(&[1, 2, 3], &[2, 4, 2]);
        assert_eq!(allowed, vec![2]);
    }

    // Ruby: test "skip_template_create? and skip_template_remove? encode idempotent sync rules"
    #[test]
    fn skip_template_rules() {
        assert!(CropTaskTemplateSyncPolicy::skip_template_create(false, false));
        assert!(CropTaskTemplateSyncPolicy::skip_template_create(true, true));
        assert!(!CropTaskTemplateSyncPolicy::skip_template_create(true, false));

        assert!(CropTaskTemplateSyncPolicy::skip_template_remove(false, true));
        assert!(CropTaskTemplateSyncPolicy::skip_template_remove(true, false));
        assert!(!CropTaskTemplateSyncPolicy::skip_template_remove(true, true));
    }

    // Ruby: test "crops_to_add and crops_to_remove compute set difference"
    #[test]
    fn crops_to_add_and_remove() {
        let allowed = vec![1, 2];
        let current = vec![2, 3];
        assert_eq!(
            CropTaskTemplateSyncPolicy::crops_to_add(&allowed, &current),
            vec![1]
        );
        assert_eq!(
            CropTaskTemplateSyncPolicy::crops_to_remove(&allowed, &current),
            vec![3]
        );
    }

    // Ruby: test "template_attributes_from_task_entity copies task fields"
    #[test]
    fn template_attributes_from_task_entity() {
        let task = AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(1),
            user_id: Some(10),
            name: "剪定".into(),
            description: Some("desc".into()),
            time_per_sqm: Some(0.5),
            weather_dependency: Some("low".into()),
            required_tools: vec!["ハサミ".into()],
            skill_level: Some("beginner".into()),
            region: Some("jp".into()),
            task_type: Some("work".into()),
            is_reference: false,
            created_at: None,
            updated_at: None,
        })
        .expect("valid");

        let attrs = CropTaskTemplateSyncPolicy::template_attributes_from_task_entity(&task);
        assert_eq!(attrs.get("name"), Some(&AttrValue::from("剪定")));
        assert_eq!(attrs.get("description"), Some(&AttrValue::from("desc")));
    }
