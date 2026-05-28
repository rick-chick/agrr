//! Ruby: `Domain::Crop::Interactors::CropCreateInteractor`

use crate::crop::dtos::{CropCreateInput, CropCreateLimitExceededFailure};
use crate::crop::entities::CropEntity;
use crate::crop::gateways::CropGateway;
use crate::crop::policies::crop_create_limit_policy;
use crate::crop::ports::{CreateFailure, CropCreateOutputPort};
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::{crop_policy, referencable_resource_policy};
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};

pub struct CropCreateInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> CropCreateInteractor<'a, G, O, U, T>
where
    G: CropGateway,
    O: CropCreateOutputPort,
    U: UserLookupGateway,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        translator: &'a T,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            translator,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        input: CropCreateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let opts = TranslateOptions::default();

        if !referencable_resource_policy::reference_assignment_allowed(&user, input.is_reference)
        {
            let message = self.translator.t("crops.flash.reference_only_admin", &opts);
            self.output_port.on_failure(CreateFailure::Error(Error::new(message)));
            return Ok(());
        }

        let mut attrs = crop_policy::normalize_attrs_for_create(
            &user,
            attr_map_from_pairs([
                ("name", AttrValue::from(input.name.as_str())),
                (
                    "variety",
                    input
                        .variety
                        .as_deref()
                        .map(AttrValue::from)
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "area_per_unit",
                    optional_float_attr(input.area_per_unit),
                ),
                (
                    "revenue_per_area",
                    optional_float_attr(input.revenue_per_area),
                ),
                (
                    "region",
                    input
                        .region
                        .as_deref()
                        .map(AttrValue::from)
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "groups",
                    AttrValue::Str(
                        serde_json::to_string(&input.groups)
                            .unwrap_or_else(|_| "[]".to_string()),
                    ),
                ),
                ("is_reference", AttrValue::Bool(input.is_reference)),
            ]),
        );

        let is_reference = attrs
            .get("is_reference")
            .map(crate::shared::type_converters::cast_boolean_attr)
            .unwrap_or(false);
        let effective_user_id = match attrs.get("user_id") {
            Some(AttrValue::Int(id)) => Some(*id),
            Some(AttrValue::Null) | None => None,
            Some(AttrValue::Str(s)) if s.is_empty() => None,
            _ => None,
        };

        if !referencable_resource_policy::reference_record_user_id_valid(
            is_reference,
            effective_user_id,
        ) {
            let message = self
                .translator
                .t("activerecord.errors.models.crop.attributes.user.blank", &opts);
            self.output_port
                .on_failure(CreateFailure::Error(Error::new(message)));
            return Ok(());
        }

        if !is_reference {
            let existing_count = self
                .gateway
                .count_user_owned_non_reference_crops(user.id)?;
            if crop_create_limit_policy::limit_exceeded(existing_count, is_reference) {
                let message = self.translator.t(
                    "activerecord.errors.models.crop.attributes.user.crop_limit_exceeded",
                    &opts,
                );
                self.output_port.on_failure(CreateFailure::LimitExceeded(
                    CropCreateLimitExceededFailure::new(message),
                ));
                return Ok(());
            }
        }

        match self.gateway.create_for_user(&user, attrs) {
            Ok(entity) => {
                self.output_port.on_success(entity);
                Ok(())
            }
            Err(err) => Self::handle_gateway_error(&mut self.output_port, err),
        }
    }

    fn handle_gateway_error(
        output_port: &mut O,
        err: Box<dyn std::error::Error + Send + Sync>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if err.downcast_ref::<RecordNotFoundError>().is_some()
            || err.downcast_ref::<RecordInvalidError>().is_some()
        {
            output_port.on_failure(CreateFailure::Error(Error::new(err.to_string())));
            return Ok(());
        }
        Err(err)
    }
}

fn optional_float_attr(value: Option<f64>) -> AttrValue {
    value
        .map(|v| AttrValue::Str(v.to_string()))
        .unwrap_or(AttrValue::Null)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            format!("t:{key}")
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct SpyOutput {
        success: Option<CropEntity>,
        failure: Option<CreateFailure>,
    }

    impl CropCreateOutputPort for SpyOutput {
        fn on_success(&mut self, entity: CropEntity) {
            self.success = Some(entity);
        }
        fn on_failure(&mut self, error: CreateFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_crop() -> CropEntity {
        CropEntity {
            id: 99,
            user_id: Some(10),
            name: "新規作物".into(),
            variety: Some("品種".into()),
            is_reference: false,
            area_per_unit: None,
            revenue_per_area: None,
            region: None,
            groups: vec![],
            created_at: None,
            updated_at: None,
        }
    }

    struct UnderLimitGateway {
        entity: CropEntity,
    }

    impl CropGateway for UnderLimitGateway {
        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
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
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn count_user_owned_non_reference_crops(
            &self,
            _: i64,
        ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            Ok(0)
        }
        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.entity.clone())
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
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
    
    fn list_by_crop_id(
            &self,
            _: i64,
        ) -> Result<
            Vec<crate::crop::entities::CropStageEntity>,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn create_crop_stage(
            &self,
            _: crate::crop::dtos::CropStageCreateInput,
        ) -> Result<
            crate::crop::entities::CropStageEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_crop_stage(
            &self,
            _: i64,
            _: crate::crop::dtos::CropStageUpdateInput,
        ) -> Result<
            crate::crop::entities::CropStageEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_crop_stage(
            &self,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
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
        fn masters_crop_agricultural_task_templates_index_rows(
            &self,
            _: i64,
        ) -> Result<Vec<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_masters_crop_task_template_for_api(
            &self,
            _: i64,
            _: i64,
            _: serde_json::Value,
        ) -> Result<
            crate::crop::gateways::UpdateMastersCropTaskTemplateOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_masters_crop_task_template(
            &self,
            _: i64,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct AtLimitGateway;
    impl CropGateway for AtLimitGateway {
        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
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
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn count_user_owned_non_reference_crops(
            &self,
            _: i64,
        ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            Ok(20)
        }
        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            panic!("create should not run")
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
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
    
    fn list_by_crop_id(
            &self,
            _: i64,
        ) -> Result<
            Vec<crate::crop::entities::CropStageEntity>,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn create_crop_stage(
            &self,
            _: crate::crop::dtos::CropStageCreateInput,
        ) -> Result<
            crate::crop::entities::CropStageEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_crop_stage(
            &self,
            _: i64,
            _: crate::crop::dtos::CropStageUpdateInput,
        ) -> Result<
            crate::crop::entities::CropStageEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_crop_stage(
            &self,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
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
        fn masters_crop_agricultural_task_templates_index_rows(
            &self,
            _: i64,
        ) -> Result<Vec<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_masters_crop_task_template_for_api(
            &self,
            _: i64,
            _: i64,
            _: serde_json::Value,
        ) -> Result<
            crate::crop::gateways::UpdateMastersCropTaskTemplateOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_masters_crop_task_template(
            &self,
            _: i64,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct AdminGateway {
        entity: CropEntity,
        count_called: std::sync::Mutex<bool>,
    }

    impl CropGateway for AdminGateway {
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
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
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn count_user_owned_non_reference_crops(
            &self,
            _: i64,
        ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            *self.count_called.lock().unwrap() = true;
            Ok(100)
        }
        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.entity.clone())
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
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
    
    fn list_by_crop_id(
            &self,
            _: i64,
        ) -> Result<
            Vec<crate::crop::entities::CropStageEntity>,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn create_crop_stage(
            &self,
            _: crate::crop::dtos::CropStageCreateInput,
        ) -> Result<
            crate::crop::entities::CropStageEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_crop_stage(
            &self,
            _: i64,
            _: crate::crop::dtos::CropStageUpdateInput,
        ) -> Result<
            crate::crop::entities::CropStageEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_crop_stage(
            &self,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
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
        fn masters_crop_agricultural_task_templates_index_rows(
            &self,
            _: i64,
        ) -> Result<Vec<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_masters_crop_task_template_for_api(
            &self,
            _: i64,
            _: i64,
            _: serde_json::Value,
        ) -> Result<
            crate::crop::gateways::UpdateMastersCropTaskTemplateOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_masters_crop_task_template(
            &self,
            _: i64,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    // Ruby: test "calls on_success when gateway returns entity"
    #[test]
    fn calls_on_success_when_gateway_returns_entity() {
        let entity = sample_crop();
        let gateway = UnderLimitGateway {
            entity: entity.clone(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(10, false));
        let mut interactor = CropCreateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &user_lookup,
        );
        interactor
            .call(CropCreateInput::new("新規作物"))
            .unwrap();
        assert_eq!(output.success, Some(entity));
    }

    // Ruby: test "calls on_failure with error dto when non-admin requests reference crop"
    #[test]
    fn calls_on_failure_when_non_admin_requests_reference_crop() {
        let gateway = UnderLimitGateway {
            entity: sample_crop(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(10, false));
        let mut interactor = CropCreateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &user_lookup,
        );
        let mut input = CropCreateInput::new("参照のみ");
        input.is_reference = true;
        interactor.call(input).unwrap();
        match output.failure {
            Some(CreateFailure::Error(e)) => assert!(e.message.contains("reference_only_admin")),
            other => panic!("expected Error failure, got {other:?}"),
        }
    }

    // Ruby: test "calls on_failure with limit exceeded dto when at crop limit"
    #[test]
    fn calls_on_failure_with_limit_exceeded_when_at_crop_limit() {
        let gateway = AtLimitGateway;
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(10, false));
        let mut interactor = CropCreateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &user_lookup,
        );
        interactor.call(CropCreateInput::new("21件目")).unwrap();
        match output.failure {
            Some(CreateFailure::LimitExceeded(f)) => {
                assert!(f.message.contains("crop_limit_exceeded"));
            }
            other => panic!("expected LimitExceeded, got {other:?}"),
        }
    }

    // Ruby: test "skips crop limit check for reference crop create by admin"
    #[test]
    fn skips_crop_limit_check_for_reference_crop_create_by_admin() {
        let entity = sample_crop();
        let gateway = AdminGateway {
            entity: entity.clone(),
            count_called: std::sync::Mutex::new(false),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup_2 = StubLookup(User::new(1, true));
        let mut interactor = CropCreateInteractor::new(
            &mut output,
            1,
            &gateway,
            &StubTranslator,
            &user_lookup_2,
        );
        let mut input = CropCreateInput::new("参照作物");
        input.is_reference = true;
        interactor.call(input).unwrap();
        assert_eq!(output.success, Some(entity));
        assert!(!*gateway.count_called.lock().unwrap());
    }
}
