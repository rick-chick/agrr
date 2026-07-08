use crate::agricultural_task::constants::schedule_item_types::FIELD_WORK;
use crate::crop::dtos::{
    MastersCropTaskScheduleBlueprint, MastersCropTaskScheduleBlueprintFailureReason,
    MastersCropTaskScheduleBlueprintUpdateInput,
};
use crate::crop::entities::CropEntity;
use crate::crop::gateways::{CropGateway, CropMastersTaskScheduleBlueprintGateway};
use crate::crop::interactors::crop_masters_task_schedule_blueprint_update_interactor::CropMastersTaskScheduleBlueprintUpdateInteractor;
use crate::crop::ports::CropMastersTaskScheduleBlueprintUpdateOutputPort;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::user::User;
use rust_decimal::Decimal;
use serde_json::json;

struct StubLookup(User);

impl UserLookupGateway for StubLookup {
    fn find(&self, _: i64) -> User {
        self.0.clone()
    }
}

struct UpdateSpy {
    success: bool,
    failure: Option<MastersCropTaskScheduleBlueprintFailureReason>,
}

impl CropMastersTaskScheduleBlueprintUpdateOutputPort for UpdateSpy {
    fn on_success(&mut self, _: MastersCropTaskScheduleBlueprint) {
        self.success = true;
    }

    fn on_failure(&mut self, failure: crate::crop::dtos::MastersCropTaskScheduleBlueprintFailure) {
        self.failure = Some(failure.reason);
    }
}

fn crop() -> CropEntity {
    CropEntity {
        id: 2,
        user_id: Some(1),
        name: "Foo".into(),
        variety: None,
        is_reference: false,
        area_per_unit: None,
        revenue_per_area: None,
        region: None,
        groups: vec![],
        created_at: None,
        updated_at: None,
    }
}

fn blueprint(id: i64, stage_order: i32, gdd_trigger: Option<i64>) -> MastersCropTaskScheduleBlueprint {
    MastersCropTaskScheduleBlueprint {
        id,
        crop_id: 2,
        agricultural_task_id: Some(3),
        source_agricultural_task_id: None,
        stage_order: Some(stage_order),
        stage_name: None,
        gdd_trigger: gdd_trigger.map(Decimal::from),
        gdd_tolerance: None,
        task_type: FIELD_WORK.into(),
        source: "manual".into(),
        priority: 1,
        amount: None,
        amount_unit: None,
        description: None,
        weather_dependency: None,
        time_per_sqm: None,
        name: None,
        created_at: None,
        updated_at: None,
    }
}

struct BlueprintGw {
    rows: Vec<MastersCropTaskScheduleBlueprint>,
}

impl CropMastersTaskScheduleBlueprintGateway for BlueprintGw {
    fn list_by_crop_id(
        &self,
        _: i64,
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.rows.clone())
    }

    fn create(
        &self,
        _: crate::crop::dtos::CropTaskScheduleBlueprintPersistAttrs,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn update(
        &self,
        _: i64,
        blueprint_id: i64,
        attributes: serde_json::Value,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
        let mut row = self
            .rows
            .iter()
            .find(|row| row.id == blueprint_id)
            .cloned()
            .expect("blueprint");
        if let Some(stage_order) = attributes.get("stage_order").and_then(|v| v.as_i64()) {
            row.stage_order = Some(stage_order as i32);
        }
        if let Some(gdd_trigger) = attributes.get("gdd_trigger").and_then(|v| v.as_f64()) {
            row.gdd_trigger = Some(Decimal::from(gdd_trigger as i64));
        }
        Ok(row)
    }

    fn delete_by_id(
        &self,
        _: i64,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn replace_all_for_crop(
        &self,
        _: i64,
        _: &[crate::crop::dtos::CropTaskScheduleBlueprintPersistAttrs],
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn delete_fertilize_blueprints_for_crop(
        &self,
        _: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn update_regenerated_field_work(
        &self,
        _: i64,
        _: i64,
        _: &crate::crop::dtos::CropTaskScheduleBlueprintPersistAttrs,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}

struct SuccessCropGw;

impl CropGateway for SuccessCropGw {
    fn list_index_for_filter(
        &self,
        _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
    ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_by_id(
        &self,
        _: i64,
    ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        Ok(crop())
    }

    fn find_crop_show_detail(
        &self,
        _: i64,
    ) -> Result<crate::crop::dtos::CropShowDetail, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_crop_record_with_stages(
        &self,
        _: i64,
    ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
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
        _: &User,
        _: crate::shared::attr::AttrMap,
    ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn update_for_user(
        &self,
        _: &User,
        _: i64,
        _: crate::shared::attr::AttrMap,
    ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_delete_usage(
        &self,
        _: i64,
    ) -> Result<crate::crop::dtos::CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn soft_delete_with_undo(
        &self,
        _: &User,
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
    ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn list_by_crop_id(
        &self,
        _: i64,
    ) -> Result<Vec<crate::crop::entities::CropStageEntity>, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn create_crop_stage(
        &self,
        _: crate::crop::dtos::CropStageCreateInput,
    ) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn update_crop_stage(
        &self,
        _: i64,
        _: crate::crop::dtos::CropStageUpdateInput,
    ) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn delete_crop_stage(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn create_thermal_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::ThermalRequirementUpdateInput,
    ) -> Result<
        crate::crop::entities::ThermalRequirementEntity,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        unimplemented!()
    }

    fn update_thermal_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::ThermalRequirementUpdateInput,
    ) -> Result<
        crate::crop::entities::ThermalRequirementEntity,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        unimplemented!()
    }

    fn delete_thermal_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
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

#[test]
fn update_fails_when_merged_attributes_duplicate_another_blueprint() {
    let mut out = UpdateSpy {
        success: false,
        failure: None,
    };
    let blueprint_gateway = BlueprintGw {
        rows: vec![
            blueprint(10, 2, Some(100)),
            blueprint(11, 2, Some(250)),
        ],
    };
    let user_lookup = StubLookup(User::new(1, false));
    let mut interactor = CropMastersTaskScheduleBlueprintUpdateInteractor::new(
        &mut out,
        &SuccessCropGw,
        &blueprint_gateway,
        &user_lookup,
    );
    interactor
        .call(MastersCropTaskScheduleBlueprintUpdateInput {
            user_id: 1,
            crop_id: 2,
            blueprint_id: 11,
            attributes: json!({"gdd_trigger": 100.0}),
        })
        .unwrap();
    assert!(!out.success);
    assert_eq!(
        out.failure,
        Some(MastersCropTaskScheduleBlueprintFailureReason::Duplicate)
    );
}

#[test]
fn update_succeeds_when_gdd_remains_unique_within_stage() {
    let mut out = UpdateSpy {
        success: false,
        failure: None,
    };
    let blueprint_gateway = BlueprintGw {
        rows: vec![
            blueprint(10, 2, Some(100)),
            blueprint(11, 2, Some(250)),
        ],
    };
    let user_lookup = StubLookup(User::new(1, false));
    let mut interactor = CropMastersTaskScheduleBlueprintUpdateInteractor::new(
        &mut out,
        &SuccessCropGw,
        &blueprint_gateway,
        &user_lookup,
    );
    interactor
        .call(MastersCropTaskScheduleBlueprintUpdateInput {
            user_id: 1,
            crop_id: 2,
            blueprint_id: 11,
            attributes: json!({"gdd_trigger": 300.0}),
        })
        .unwrap();
    assert!(out.success);
}
