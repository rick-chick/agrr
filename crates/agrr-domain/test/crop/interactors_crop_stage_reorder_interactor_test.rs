// Tests for `interactors/crop_stage_reorder_interactor.rs`

    use crate::crop::dtos::CropStageReorderEntry;
    use crate::crop::entities::CropStageEntity;
    use crate::shared::exceptions::RecordInvalidError;

    struct SpyOutput {
        success: Option<CropStageListOutput>,
        failure: Option<CropStageReorderFailure>,
    }

    impl CropStageReorderOutputPort for SpyOutput {
        fn on_success(&mut self, output: CropStageListOutput) {
            self.success = Some(output);
        }
        fn on_failure(&mut self, error: CropStageReorderFailure) {
            self.failure = Some(error);
        }
    }

    struct ReorderGateway {
        ok: Option<Vec<CropStageEntity>>,
        invalid: bool,
        boom: bool,
    }

    impl CropGateway for ReorderGateway {
        fn reorder_crop_stages(
            &self,
            crop_id: i64,
            stage_orders: Vec<(i64, i64)>,
        ) -> Result<Vec<CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(crop_id, 10);
            assert_eq!(stage_orders, vec![(1, 2), (2, 1)]);
            if self.boom {
                return Err("reorder failed".into());
            }
            if self.invalid {
                return Err(Box::new(RecordInvalidError::new(
                    Some("order has already been taken".into()),
                    None,
                )));
            }
            Ok(self.ok.clone().unwrap())
        }

        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn find_crop_show_detail(
            &self,
            _: i64,
        ) -> Result<crate::crop::dtos::CropShowDetail, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn find_crop_record_with_stages(
            &self,
            _: i64,
        ) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn count_user_owned_non_reference_crops(
            &self,
            _: i64,
        ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &crate::shared::user::User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &crate::shared::user::User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<crate::crop::dtos::CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &crate::shared::user::User,
            _: i64,
            _: i64,
            _: &str,
        ) -> Result<
            crate::crop::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn list_by_crop_id(
            &self,
            _: i64,
        ) -> Result<Vec<CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_crop_stage(
            &self,
            _: crate::crop::dtos::CropStageCreateInput,
        ) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_crop_stage(
            &self,
            _: i64,
            _: crate::crop::dtos::CropStageUpdateInput,
        ) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn delete_crop_stage(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_thermal_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::ThermalRequirementUpdateInput,
        ) -> Result<crate::crop::entities::ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn update_thermal_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::ThermalRequirementUpdateInput,
        ) -> Result<crate::crop::entities::ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn delete_thermal_requirement(
            &self,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_temperature_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::TemperatureRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::TemperatureRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_temperature_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::TemperatureRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::TemperatureRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_temperature_requirement(
            &self,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_sunshine_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::SunshineRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::SunshineRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_sunshine_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::SunshineRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::SunshineRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_sunshine_requirement(
            &self,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_nutrient_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::NutrientRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::NutrientRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_nutrient_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::NutrientRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::NutrientRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_nutrient_requirement(
            &self,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    fn stage(id: i64, crop_id: i64, order: i64) -> CropStageEntity {
        CropStageEntity::new(id, crop_id, format!("Stage {id}"), order as i32).unwrap()
    }

    #[test]
    fn calls_on_success_when_gateway_reorders_stages() {
        let gateway = ReorderGateway {
            ok: Some(vec![stage(2, 10, 1), stage(1, 10, 2)]),
            invalid: false,
            boom: false,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut interactor = CropStageReorderInteractor::new(&mut output, &gateway);
        interactor
            .call(CropStageReorderInput {
                crop_id: 10,
                entries: vec![
                    CropStageReorderEntry {
                        crop_stage_id: 1,
                        order: 2,
                    },
                    CropStageReorderEntry {
                        crop_stage_id: 2,
                        order: 1,
                    },
                ],
            })
            .unwrap();

        let success = output.success.expect("success");
        assert_eq!(success.stages.len(), 2);
        assert!(output.failure.is_none());
    }

    #[test]
    fn calls_on_failure_when_gateway_returns_record_invalid() {
        let gateway = ReorderGateway {
            ok: None,
            invalid: true,
            boom: false,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut interactor = CropStageReorderInteractor::new(&mut output, &gateway);
        interactor
            .call(CropStageReorderInput {
                crop_id: 10,
                entries: vec![
                    CropStageReorderEntry {
                        crop_stage_id: 1,
                        order: 2,
                    },
                    CropStageReorderEntry {
                        crop_stage_id: 2,
                        order: 1,
                    },
                ],
            })
            .unwrap();

        assert!(output.success.is_none());
        assert!(matches!(output.failure, Some(CropStageReorderFailure::Error(_))));
    }

    #[test]
    fn rejects_duplicate_orders_before_gateway_call() {
        let gateway = ReorderGateway {
            ok: Some(vec![]),
            invalid: false,
            boom: true,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut interactor = CropStageReorderInteractor::new(&mut output, &gateway);
        interactor
            .call(CropStageReorderInput {
                crop_id: 10,
                entries: vec![
                    CropStageReorderEntry {
                        crop_stage_id: 1,
                        order: 1,
                    },
                    CropStageReorderEntry {
                        crop_stage_id: 2,
                        order: 1,
                    },
                ],
            })
            .unwrap();

        assert!(output.success.is_none());
        assert!(matches!(output.failure, Some(CropStageReorderFailure::Error(_))));
    }
