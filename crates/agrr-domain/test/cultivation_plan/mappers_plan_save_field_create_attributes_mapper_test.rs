// Tests for `mappers/plan_save_field_create_attributes_mapper.rs` (Ruby parity under test/domain/cultivation_plan/).


    struct FakeTranslator;

    impl PlanSaveFieldTranslator for FakeTranslator {
        fn coordinates_message(&self, lat: f64, lng: f64) -> String {
            // Match Ruby `opts.sort.to_h.inspect` for Float coords (35.0 not 35).
            fn ruby_float(v: f64) -> String {
                if v.fract().abs() < f64::EPSILON {
                    format!("{v:.1}")
                } else {
                    v.to_string()
                }
            }
            format!(
                "services.plan_save_service.messages.coordinates|{{:lat=>{}, :lng=>{}}}",
                ruby_float(lat),
                ruby_float(lng)
            )
        }
    }

    // Ruby: test "attributes_for_create adds description from coordinates"
    #[test]
    fn attributes_for_create_adds_description_from_coordinates() {
        let datum = PublicPlanSaveFieldDatum::new(
            Some("区画A"),
            Some(12.5),
            vec![35.0, 139.0],
        );

        let attrs = attributes_for_create(&datum, &FakeTranslator);

        assert_eq!(attrs["name"].as_str(), Some("区画A"));
        assert!((attrs["area"].as_f64().unwrap() - 12.5).abs() < 0.001);
        assert_eq!(
            attrs["description"].as_str(),
            Some("services.plan_save_service.messages.coordinates|{:lat=>35.0, :lng=>139.0}")
        );
    }

    // Ruby: test "attributes_for_create omits description without coordinates"
    #[test]
    fn attributes_for_create_omits_description_without_coordinates() {
        let datum = PublicPlanSaveFieldDatum::new(Some("区画B"), Some(3.0), vec![]);

        let attrs = attributes_for_create(&datum, &FakeTranslator);

        assert!(!attrs.contains_key("description"));
    }
