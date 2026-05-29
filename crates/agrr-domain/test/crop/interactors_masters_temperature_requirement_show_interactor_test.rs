// Tests for `interactors/masters_temperature_requirement_show_interactor.rs` (Ruby parity under test/domain/crop/).

    use crate::crop::entities::TemperatureRequirementEntity;

    struct StubGw { found: bool }
    impl TemperatureRequirementGateway for StubGw {
        fn find_by_crop_stage_id(&self, _: i64) -> Result<Option<TemperatureRequirementEntity>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(if self.found { Some(TemperatureRequirementEntity::new(1, 9).unwrap()) } else { None })
        }
    }
    struct Spy { event: Option<&'static str> }
    impl MastersTemperatureRequirementOutputPort for Spy {
        fn on_show_success(&mut self, _: TemperatureRequirementEntity) { self.event = Some("show"); }
        fn on_create_success(&mut self, _: TemperatureRequirementEntity) {}
        fn on_update_success(&mut self, _: TemperatureRequirementEntity) {}
        fn on_destroy_success(&mut self) {}
        fn on_not_found(&mut self) { self.event = Some("not_found"); }
        fn on_already_exists(&mut self) {}
        fn on_validation_errors(&mut self, _: Vec<String>) {}
    }

    // Ruby: test "renders show success when requirement exists"
    #[test]
    fn renders_show_success_when_requirement_exists() {
        let gw = StubGw { found: true };
        let mut out = Spy { event: None };
        let mut i = MastersTemperatureRequirementShowInteractor::new(&mut out, &gw);
        i.call(CropStageDetailInput { crop_stage_id: 9 }).unwrap();
        assert_eq!(out.event, Some("show"));
    }

    // Ruby: test "renders not found when requirement missing"
    #[test]
    fn renders_not_found_when_requirement_missing() {
        let gw = StubGw { found: false };
        let mut out = Spy { event: None };
        let mut i = MastersTemperatureRequirementShowInteractor::new(&mut out, &gw);
        i.call(CropStageDetailInput { crop_stage_id: 9 }).unwrap();
        assert_eq!(out.event, Some("not_found"));
    }
