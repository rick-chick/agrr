// Tests for `interactors/crop_stage_detail_interactor.rs` (Ruby parity under test/domain/crop/).

    use crate::crop::entities::CropStageEntity;

    struct Spy {
        success: Option<CropStageOutput>,
        failure: Option<CropStageDetailFailure>,
    }

    impl CropStageDetailOutputPort for Spy {
        fn on_success(&mut self, output: CropStageOutput) {
            self.success = Some(output);
        }
        fn on_failure(&mut self, error: CropStageDetailFailure) {
            self.failure = Some(error);
        }
    }

    struct StageGw {
        ok: Option<CropStageEntity>,
        invalid: bool,
        boom: bool,
    }

    impl CropStageGateway for StageGw {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
            if self.boom {
                return Err("detail failed".into());
            }
            if self.invalid {
                return Err(Box::new(RecordInvalidError::new(
                    Some("invalid".into()),
                    None,
                )));
            }
            Ok(self.ok.clone().unwrap())
        }
    }

    // Ruby: test "calls on_success with crop stage when gateway succeeds"
    #[test]
    fn calls_on_success_with_crop_stage_when_gateway_succeeds() {
        let stage = CropStageEntity::new(1, 1, "発芽", 1).unwrap();
        let gw = StageGw {
            ok: Some(stage.clone()),
            invalid: false,
            boom: false,
        };
        let mut out = Spy {
            success: None,
            failure: None,
        };
        let mut i = CropStageDetailInteractor::new(&mut out, &gw);
        i.call(CropStageDetailInput {
            crop_stage_id: 1,
        })
        .unwrap();
        assert_eq!(out.success.unwrap().stage, stage);
    }

    // Ruby: test "calls on_failure with Error when gateway raises RecordInvalid"
    #[test]
    fn calls_on_failure_when_gateway_raises_record_invalid() {
        let gw = StageGw {
            ok: None,
            invalid: true,
            boom: false,
        };
        let mut out = Spy {
            success: None,
            failure: None,
        };
        let mut i = CropStageDetailInteractor::new(&mut out, &gw);
        i.call(CropStageDetailInput {
            crop_stage_id: 1,
        })
        .unwrap();
        assert!(matches!(out.failure, Some(CropStageDetailFailure::Error(_))));
    }

    // Ruby: test "propagates StandardError when gateway raises"
    #[test]
    fn propagates_standard_error_when_gateway_raises() {
        let gw = StageGw {
            ok: None,
            invalid: false,
            boom: true,
        };
        let mut out = Spy {
            success: None,
            failure: None,
        };
        let mut i = CropStageDetailInteractor::new(&mut out, &gw);
        let err = i
            .call(CropStageDetailInput {
                crop_stage_id: 1,
            })
            .unwrap_err();
        assert!(err.to_string().contains("detail failed"));
    }
