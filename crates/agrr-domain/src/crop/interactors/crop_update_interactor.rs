//! Ruby: `Domain::Crop::Interactors::CropUpdateInteractor`

use crate::crop::dtos::CropUpdateInput;
use crate::crop::entities::CropEntity;
use crate::crop::gateways::CropGateway;
use crate::crop::ports::{CropUpdateOutputPort, UpdateFailure};
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::dtos::{Error, ReferenceFlagChangeDeniedFailure};
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::policies::referencable_resource_policy::{
    reference_flag_change_allowed, reference_record_user_id_valid,
};
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;
use crate::shared::type_converters::cast_boolean_attr;

pub struct CropUpdateInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> CropUpdateInteractor<'a, G, O, U, T>
where
    G: CropGateway,
    O: CropUpdateOutputPort,
    U: UserLookupGateway,
    T: TranslatorPort,
{
    pub fn new(output_port: &'a mut O, user_id: i64, gateway: &'a G, translator: &'a T, user_lookup: &'a U) -> Self {
        Self { output_port, gateway, user_id, translator, user_lookup }
    }

    pub fn call(&mut self, input: CropUpdateInput) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = crop_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let current = match self.gateway.find_by_id(input.crop_id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    self.output_port.on_failure(UpdateFailure::Error(Error::new(err.to_string())));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(policy) = reference_record_authorization::assert_edit_allowed(&access_filter, &current) {
            self.output_port.on_failure(UpdateFailure::Policy(policy));
            return Ok(());
        }

        if let Some(is_reference) = input.is_reference {
            if !reference_flag_change_allowed(&user, is_reference, current.reference()) {
                let message = self.translator.t("crops.flash.reference_flag_admin_only", &opts);
                self.output_port.on_failure(UpdateFailure::ReferenceFlagChangeDenied(
                    ReferenceFlagChangeDeniedFailure::new(message, input.crop_id),
                ));
                return Ok(());
            }
        }

        let mut attrs = AttrMap::new();
        if let Some(name) = input.name { attrs.insert("name".into(), AttrValue::from(name.as_str())); }
        if let Some(variety) = input.variety { attrs.insert("variety".into(), AttrValue::from(variety.as_str())); }
        if let Some(v) = input.area_per_unit { attrs.insert("area_per_unit".into(), AttrValue::Str(v.to_string())); }
        if let Some(v) = input.revenue_per_area { attrs.insert("revenue_per_area".into(), AttrValue::Str(v.to_string())); }
        if let Some(region) = input.region { attrs.insert("region".into(), AttrValue::from(region.as_str())); }
        if let Some(groups) = input.groups {
            attrs.insert(
                "groups".into(),
                AttrValue::Str(
                    serde_json::to_string(&groups).unwrap_or_else(|_| "[]".to_string()),
                ),
            );
        }
        if let Some(is_reference) = input.is_reference { attrs.insert("is_reference".into(), AttrValue::Bool(is_reference)); }

        let normalized = crop_policy::normalize_attrs_for_update(
            &user,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(current.reference()))]),
            attrs,
        );
        let effective_reference = normalized.get("is_reference").map(cast_boolean_attr).unwrap_or(current.reference());
        let effective_user_id = normalized.get("user_id").map(|v| match v {
            AttrValue::Int(id) => Some(*id),
            AttrValue::Null => None,
            _ => current.user_id,
        }).unwrap_or(current.user_id);

        if !reference_record_user_id_valid(effective_reference, effective_user_id) {
            let message = self.translator.t("activerecord.errors.models.crop.attributes.user.blank", &opts);
            self.output_port.on_failure(UpdateFailure::Error(Error::new(message)));
            return Ok(());
        }

        match self.gateway.update_for_user(&user, input.crop_id, normalized) {
            Ok(entity) => { self.output_port.on_success(entity); Ok(()) }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(record_invalid) => {
                    self.output_port.on_failure(UpdateFailure::Error(Error::new(record_invalid.to_string())));
                    Ok(())
                }
                Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                    self.output_port.on_failure(UpdateFailure::Error(Error::new(err.to_string())));
                    Ok(())
                }
                Err(err) => Err(err),
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup { fn find(&self, _: i64) -> User { self.0 } }
    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String { format!("t:{key}") }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String { String::new() }
    }
    struct SpyOutput { success: Option<CropEntity>, failure: Option<UpdateFailure> }
    impl CropUpdateOutputPort for SpyOutput {
        fn on_success(&mut self, e: CropEntity) { self.success = Some(e); }
        fn on_failure(&mut self, e: UpdateFailure) { self.failure = Some(e); }
    }
    fn crop(user_id: i64) -> CropEntity {
        CropEntity { id: 5, user_id: Some(user_id), name: "n".into(), variety: None, is_reference: false, area_per_unit: None, revenue_per_area: None, region: None, groups: vec![], created_at: None, updated_at: None }
    }
    struct UpdateGw { current: CropEntity, updated: CropEntity, deny_edit: bool }
    impl CropGateway for UpdateGw {

        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(&self, _: i64) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> { Ok(self.current.clone()) }
        fn update_for_user(&self, _: &User, _: i64, _: AttrMap) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            if self.deny_edit { panic!("update should not run") }
            Ok(self.updated.clone())
        }

        fn list_index_for_filter(&self, _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_crop_show_detail(&self, _: i64) -> Result<crate::crop::dtos::CropShowDetail, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_crop_record_with_stages(&self, _: i64) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn count_user_owned_non_reference_crops(&self, _: i64) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_for_user(&self, _: &crate::shared::user::User, _: crate::shared::attr::AttrMap) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_delete_usage(&self, _: i64) -> Result<crate::crop::dtos::CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn soft_delete_with_undo(&self, _: &crate::shared::user::User, _: i64, _: i64, _: &str) -> Result<crate::crop::gateways::SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
    
    fn list_by_crop_id(&self, _: i64) -> Result<Vec<crate::crop::entities::CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_crop_stage(&self, _: crate::crop::dtos::CropStageCreateInput) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_crop_stage(&self, _: i64, _: crate::crop::dtos::CropStageUpdateInput) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_crop_stage(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_thermal_requirement(&self, _: i64, _: crate::crop::dtos::ThermalRequirementUpdateInput) -> Result<crate::crop::entities::ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_thermal_requirement(&self, _: i64, _: crate::crop::dtos::ThermalRequirementUpdateInput) -> Result<crate::crop::entities::ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_thermal_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_temperature_requirement(&self, _: i64, _: crate::crop::dtos::TemperatureRequirementUpdateInput) -> Result<crate::crop::entities::TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_temperature_requirement(&self, _: i64, _: crate::crop::dtos::TemperatureRequirementUpdateInput) -> Result<crate::crop::entities::TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_temperature_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_sunshine_requirement(&self, _: i64, _: crate::crop::dtos::SunshineRequirementUpdateInput) -> Result<crate::crop::entities::SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_sunshine_requirement(&self, _: i64, _: crate::crop::dtos::SunshineRequirementUpdateInput) -> Result<crate::crop::entities::SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_sunshine_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_nutrient_requirement(&self, _: i64, _: crate::crop::dtos::NutrientRequirementUpdateInput) -> Result<crate::crop::entities::NutrientRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_nutrient_requirement(&self, _: i64, _: crate::crop::dtos::NutrientRequirementUpdateInput) -> Result<crate::crop::entities::NutrientRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_nutrient_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn masters_crop_agricultural_task_templates_index_rows(&self, _: i64) -> Result<Vec<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_masters_crop_task_template_for_api(&self, _: i64, _: i64, _: serde_json::Value) -> Result<crate::crop::gateways::UpdateMastersCropTaskTemplateOutcome, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_masters_crop_task_template(&self, _: i64, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }

    }

    // Ruby: test "calls on_success when gateway returns entity"
    #[test]
    fn calls_on_success_when_gateway_returns_entity() {
        let updated = crop(10);
        let gw = UpdateGw { current: crop(10), updated: updated.clone(), deny_edit: false };
        let mut out = SpyOutput { success: None, failure: None };
        let user_lookup = StubLookup(User::new(10, false));
        let mut i = CropUpdateInteractor::new(&mut out, 10, &gw, &StubTranslator, &user_lookup);
        let mut input = CropUpdateInput::new(5);
        input.name = Some("更新された名前".into());
        i.call(input).unwrap();
        assert_eq!(out.success, Some(updated));
    }

    // Ruby: test "calls on_failure with policy exception when permission denied"
    #[test]
    fn calls_on_failure_with_policy_when_permission_denied() {
        let gw = UpdateGw { current: crop(99), updated: crop(10), deny_edit: true };
        let mut out = SpyOutput { success: None, failure: None };
        let user_lookup = StubLookup(User::new(10, false));
        let mut i = CropUpdateInteractor::new(&mut out, 10, &gw, &StubTranslator, &user_lookup);
        i.call(CropUpdateInput::new(5)).unwrap();
        assert!(matches!(out.failure, Some(UpdateFailure::Policy(PolicyPermissionDenied))));
    }

    // Ruby: test "calls on_failure with error dto when non-admin toggles is_reference"
    #[test]
    fn calls_on_failure_when_non_admin_toggles_is_reference() {
        let gw = UpdateGw { current: crop(10), updated: crop(10), deny_edit: false };
        let mut out = SpyOutput { success: None, failure: None };
        let user_lookup = StubLookup(User::new(10, false));
        let mut i = CropUpdateInteractor::new(&mut out, 10, &gw, &StubTranslator, &user_lookup);
        let mut input = CropUpdateInput::new(5);
        input.is_reference = Some(true);
        i.call(input).unwrap();
        assert!(matches!(out.failure, Some(UpdateFailure::ReferenceFlagChangeDenied(_))));
    }
}
