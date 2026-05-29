// Tests for `policies/masters_crop_task_template_create_policy.rs` (Ruby parity under test/domain/crop/).

    use crate::agricultural_task::entities::AgriculturalTaskEntityAttrs;

    // Ruby: test "duplicate? is true when link exists"
    #[test]
    fn duplicate_when_link_exists() {
        let link = CropTaskTemplateEntity {
            id: 1,
            crop_id: 1,
            agricultural_task_id: 2,
            name: "t".into(),
            description: None,
            time_per_sqm: None,
            weather_dependency: None,
            required_tools: vec![],
            skill_level: None,
            created_at: None,
            updated_at: None,
        };
        assert!(duplicate(Some(&link)));
        assert!(!duplicate(None));
    }

    // Ruby: test "build_persist_attributes falls back to task entity fields"
    #[test]
    fn build_persist_attributes_falls_back_to_task() {
        let input = MastersCropTaskTemplateCreateInput::new(1, 1, Some(10));
        let task = AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(10),
            user_id: Some(1),
            name: "Task".into(),
            description: Some("desc".into()),
            is_reference: false,
            time_per_sqm: Some(1.0),
            weather_dependency: Some("sunny".into()),
            required_tools: vec!["hoe".into()],
            skill_level: Some("basic".into()),
            ..Default::default()
        })
        .expect("valid");
        let attrs = build_persist_attributes(&input, &task);
        assert_eq!(attrs.name, "Task");
        assert_eq!(attrs.description.as_deref(), Some("desc"));
    }

    // Ruby: test "to_masters_dto embeds agricultural task snapshot"
    #[test]
    fn to_masters_dto_embeds_task_snapshot() {
        let template = CropTaskTemplateEntity {
            id: 5,
            crop_id: 1,
            agricultural_task_id: 10,
            name: "Tpl".into(),
            description: None,
            time_per_sqm: None,
            weather_dependency: None,
            required_tools: vec![],
            skill_level: None,
            created_at: None,
            updated_at: None,
        };
        let task = AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(10),
            user_id: Some(1),
            name: "Task".into(),
            is_reference: true,
            ..Default::default()
        })
        .expect("valid");
        let dto = to_masters_dto(&template, &task);
        assert_eq!(dto.agricultural_task.id, 10);
        assert!(dto.agricultural_task.is_reference);
    }
