//! Ruby: `Domain::AgriculturalTask::Interactors::AgriculturalTaskUpdateInteractor`

use std::collections::HashSet;

use crate::agricultural_task::dtos::AgriculturalTaskUpdateInput;
use crate::agricultural_task::entities::AgriculturalTaskEntity;
use crate::agricultural_task::gateways::{
    AgriculturalTaskGateway, CropGateway, CropTaskTemplateGateway,
};
use crate::agricultural_task::interactors::attr_helpers::{attr_is_reference, attr_user_id, str_present};
use crate::agricultural_task::policies::CropTaskTemplateSyncPolicy;
use crate::agricultural_task::ports::{AgriculturalTaskUpdateOutputPort, UpdateFailure};
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::dtos::{Error, ReferenceFlagChangeDeniedFailure};
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::agricultural_task_policy;
use crate::shared::policies::crop_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::policies::referencable_resource_policy::{
    duplicate_name_record, reference_flag_change_allowed, reference_record_user_id_valid,
};
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;
use crate::shared::type_converters::cast_boolean_attr;

pub struct AgriculturalTaskUpdateInteractor<'a, G, CG, TG, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    crop_gateway: &'a CG,
    crop_task_template_gateway: &'a TG,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, CG, TG, O, U, T> AgriculturalTaskUpdateInteractor<'a, G, CG, TG, O, U, T>
where
    G: AgriculturalTaskGateway,
    CG: CropGateway,
    TG: CropTaskTemplateGateway,
    O: AgriculturalTaskUpdateOutputPort,
    U: UserLookupGateway,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        crop_gateway: &'a CG,
        crop_task_template_gateway: &'a TG,
        translator: &'a T,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            gateway,
            crop_gateway,
            crop_task_template_gateway,
            user_id,
            translator,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        update_input: AgriculturalTaskUpdateInput,
    ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = agricultural_task_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let current = match self.gateway.find_by_id(update_input.id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    self.output_port
                        .on_failure(UpdateFailure::Error(Error::new(err.to_string())));
                    return Ok(false);
                }
                return Err(err);
            }
        };

        if let Err(policy) =
            reference_record_authorization::assert_edit_allowed(&access_filter, &current)
        {
            self.output_port.on_failure(UpdateFailure::Policy(policy));
            return Ok(false);
        }

        if let Some(requested_ref) = update_input.is_reference {
            let requested = requested_ref;
            if !reference_flag_change_allowed(&user, requested, current.reference()) {
                let message = self
                    .translator
                    .t("agricultural_tasks.flash.reference_flag_admin_only", &opts);
                self.output_port.on_failure(UpdateFailure::ReferenceFlag(
                    ReferenceFlagChangeDeniedFailure::new(message, update_input.id),
                ));
                return Ok(false);
            }
        }

        let mut attrs = AttrMap::new();
        if str_present(&update_input.name) {
            if let Some(name) = update_input.name {
                attrs.insert("name".into(), AttrValue::from(name.as_str()));
            }
        }
        if let Some(v) = update_input.description {
            attrs.insert("description".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = update_input.time_per_sqm {
            attrs.insert("time_per_sqm".into(), AttrValue::Str(v.to_string()));
        }
        if let Some(v) = update_input.weather_dependency {
            attrs.insert("weather_dependency".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = update_input.required_tools {
            attrs.insert("required_tools".into(), AttrValue::Str(v.join(",")));
        }
        if let Some(v) = update_input.skill_level {
            attrs.insert("skill_level".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = update_input.region {
            attrs.insert("region".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = update_input.task_type {
            attrs.insert("task_type".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = update_input.is_reference {
            attrs.insert("is_reference".into(), AttrValue::Bool(v));
        }

        let sync_ids = update_input.selected_crop_ids;
        let normalized = agricultural_task_policy::normalize_attrs_for_update(
            &user,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(current.reference()))]),
            attrs,
        );

        let effective_reference = normalized
            .get("is_reference")
            .map(cast_boolean_attr)
            .unwrap_or(current.reference());
        let effective_user_id = match normalized.get("user_id") {
            Some(AttrValue::Int(id)) => Some(*id),
            Some(AttrValue::Null) => None,
            _ => current.user_id,
        };

        if !reference_record_user_id_valid(effective_reference, effective_user_id) {
            let message = self.translator.t(
                "activerecord.errors.models.agricultural_task.attributes.user.blank",
                &opts,
            );
            self.output_port
                .on_failure(UpdateFailure::Error(Error::new(message)));
            return Ok(false);
        }

        if normalized.contains_key("name") {
            let name = normalized
                .get("name")
                .and_then(|v| match v {
                    AttrValue::Str(s) => Some(s.as_str()),
                    _ => None,
                })
                .unwrap_or("");
            let existing = self.find_existing_by_name(effective_reference, effective_user_id, name)?;
            if duplicate_name_record(existing.and_then(|e| e.id), Some(update_input.id)) {
                let message = self.translator.t(
                    "activerecord.errors.models.agricultural_task.attributes.name.taken",
                    &opts,
                );
                self.output_port
                    .on_failure(UpdateFailure::Error(Error::new(message)));
                return Ok(false);
            }
        }

        let task_entity = self.gateway.within_transaction(|| {
            let entity = self.gateway.update(update_input.id, normalized)?;
            if let Some(selected_crop_ids) = sync_ids {
                self.sync_crop_task_templates(&entity, &selected_crop_ids, &user)?;
            }
            Ok::<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>>(entity)
        })?;

        self.output_port.on_success(task_entity);
        Ok(true)
    }

    fn find_existing_by_name(
        &self,
        is_reference: bool,
        user_id: Option<i64>,
        name: &str,
    ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        if is_reference {
            self.gateway.find_by_reference_and_name(name)
        } else {
            self.gateway
                .find_by_user_id_and_name(user_id.unwrap_or(self.user_id), name)
        }
    }

    fn sync_crop_task_templates(
        &self,
        task_entity: &AgriculturalTaskEntity,
        selected_crop_ids: &[i64],
        user: &crate::shared::user::User,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let region_filter =
            CropTaskTemplateSyncPolicy::crop_associate_region_filter(task_entity.region.as_deref());
        let scope_crop_ids = self.associate_scope_crop_ids(task_entity, region_filter.as_deref(), user)?;
        let scope_crop_id_set: HashSet<i64> = scope_crop_ids.iter().copied().collect();
        let allowed_crop_ids =
            CropTaskTemplateSyncPolicy::allowed_crop_ids(&scope_crop_ids, selected_crop_ids);
        let current_template_crop_ids = self
            .crop_task_template_gateway
            .list_by_agricultural_task_id(task_entity.id.unwrap_or(0))?
            .into_iter()
            .map(|link| link.crop_id)
            .collect::<Vec<_>>();
        let crops_to_add = CropTaskTemplateSyncPolicy::crops_to_add(
            &allowed_crop_ids,
            &current_template_crop_ids,
        );
        let crops_to_remove = CropTaskTemplateSyncPolicy::crops_to_remove(
            &allowed_crop_ids,
            &current_template_crop_ids,
        );
        let template_attrs =
            CropTaskTemplateSyncPolicy::template_attributes_from_task_entity(task_entity);
        let task_id = task_entity.id.unwrap_or(0);

        for crop_id in crops_to_add {
            let crop_found = scope_crop_id_set.contains(&crop_id);
            let template_exists = self.template_link_exists(task_id, crop_id)?;
            if CropTaskTemplateSyncPolicy::skip_template_create(crop_found, template_exists) {
                continue;
            }
            self.crop_task_template_gateway
                .create(task_id, crop_id, template_attrs.clone())?;
        }

        for crop_id in crops_to_remove {
            let crop_found = self.crop_record_exists(crop_id);
            let template_exists = self.template_link_exists(task_id, crop_id)?;
            if CropTaskTemplateSyncPolicy::skip_template_remove(crop_found, template_exists) {
                continue;
            }
            self.crop_task_template_gateway.delete(task_id, crop_id)?;
        }

        Ok(())
    }

    fn associate_scope_crop_ids(
        &self,
        task_entity: &AgriculturalTaskEntity,
        region_filter: Option<&str>,
        user: &crate::shared::user::User,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
        if task_entity.reference() {
            Ok(self
                .crop_gateway
                .list_by_is_reference(true, region_filter)?
                .into_iter()
                .map(|c| c.id)
                .collect())
        } else {
            Ok(self
                .crop_gateway
                .list_by_user_id(task_entity.user_id.unwrap_or(self.user_id), region_filter)?
                .into_iter()
                .filter(|crop| {
                    crop_policy::edit_allowed(user, crop.is_reference, crop.user_id)
                })
                .map(|c| c.id)
                .collect())
        }
    }

    fn crop_record_exists(&self, crop_id: i64) -> bool {
        self.crop_gateway.find_by_id(crop_id).is_ok()
    }

    fn template_link_exists(
        &self,
        agricultural_task_id: i64,
        crop_id: i64,
    ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self
            .crop_task_template_gateway
            .find_by_agricultural_task_id_and_crop_id(agricultural_task_id, crop_id)?
            .is_some())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::agricultural_task::entities::{AgriculturalTaskEntity, AgriculturalTaskEntityAttrs};
    use crate::agricultural_task::entities::CropTaskTemplateLinkEntity;
    use crate::agricultural_task::gateways::CropRecord;
    use crate::shared::user::User;

    struct MockUserLookup {
        user: User,
    }

    impl UserLookupGateway for MockUserLookup {
        fn find(&self, _user_id: i64) -> User {
            self.user
        }
    }

    struct StubTranslator;

    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            key.to_string()
        }

        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct SpyOutput {
        success: Option<AgriculturalTaskEntity>,
        failure: Option<UpdateFailure>,
    }

    impl AgriculturalTaskUpdateOutputPort for SpyOutput {
        fn on_success(&mut self, entity: AgriculturalTaskEntity) {
            self.success = Some(entity);
        }

        fn on_failure(&mut self, error: UpdateFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_current(user_id: i64) -> AgriculturalTaskEntity {
        AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(5),
            user_id: Some(user_id),
            name: "old".into(),
            description: None,
            time_per_sqm: None,
            weather_dependency: None,
            required_tools: vec![],
            skill_level: None,
            region: Some("jp".into()),
            task_type: None,
            is_reference: false,
            created_at: None,
            updated_at: None,
        })
        .expect("valid")
    }

    struct NullCropGateways;

    impl CropGateway for NullCropGateways {
        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<CropRecord>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }

        fn list_by_user_id(
            &self,
            _: i64,
            _: Option<&str>,
        ) -> Result<Vec<CropRecord>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }

    
    fn find_by_id(
            &self,
            _: i64,
        ) -> Result<CropRecord, Box<dyn std::error::Error + Send + Sync>> {
            Err(Box::new(RecordNotFoundError))
        }
    }

    struct NullTemplateGateway;

    impl CropTaskTemplateGateway for NullTemplateGateway {
        fn list_by_agricultural_task_id(
            &self,
            _: i64,
        ) -> Result<Vec<CropTaskTemplateLinkEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }

        fn find_by_agricultural_task_id_and_crop_id(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<CropTaskTemplateLinkEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(None)
        }

        fn create(
            &self,
            _: i64,
            _: i64,
            _: AttrMap,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }

        fn delete(
            &self,
            _: i64,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
    }

    // Ruby: test "calls on_success when gateway updates"
    #[test]
    fn calls_on_success_when_gateway_updates() {
        let user_id = 10;
        let current = sample_current(user_id);
        let updated = AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(5),
            user_id: Some(user_id),
            name: "剪定".into(),
            description: None,
            time_per_sqm: None,
            weather_dependency: None,
            required_tools: vec![],
            skill_level: None,
            region: Some("jp".into()),
            task_type: None,
            is_reference: false,
            created_at: None,
            updated_at: None,
        })
        .expect("valid");

        struct UpdateGateway {
            current: AgriculturalTaskEntity,
            updated: AgriculturalTaskEntity,
        }

        impl AgriculturalTaskGateway for UpdateGateway {
            fn list_user_owned_tasks(
                &self,
                _: i64,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn list_reference_tasks(
                &self,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn list_user_and_reference_tasks(
                &self,
                _: i64,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn find_agricultural_task_show_detail(
                &self,
                _: i64,
            ) -> Result<
                crate::agricultural_task::dtos::AgriculturalTaskShowDetail,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }

            fn find_by_id(
                &self,
                _: i64,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                Ok(self.current.clone())
            }

            fn find_by_reference_and_name(
                &self,
                _: &str,
            ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                Ok(None)
            }

            fn find_by_user_id_and_name(
                &self,
                _: i64,
                _: &str,
            ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                Ok(None)
            }

            fn create(
                &self,
                _: AttrMap,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }

            fn update(
                &self,
                _: i64,
                _: AttrMap,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                Ok(self.updated.clone())
            }

            fn within_transaction<F, T>(&self, block: F) -> T
            where
                F: FnOnce() -> T,
            {
                block()
            }

            fn soft_delete_with_undo(
                &self,
                _: &User,
                _: i64,
                _: i64,
                _: &str,
            ) -> Result<
                crate::agricultural_task::gateways::SoftDeleteUndoResult,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }
        }

        let gateway = UpdateGateway {
            current,
            updated: updated.clone(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = MockUserLookup {
            user: User::new(user_id, false),
        };
        let mut interactor = AgriculturalTaskUpdateInteractor::new(
            &mut output,
            user_id,
            &gateway,
            &NullCropGateways,
            &NullTemplateGateway,
            &StubTranslator,
            &user_lookup,
        );
        let input = AgriculturalTaskUpdateInput {
            id: 5,
            name: Some("剪定".into()),
            ..Default::default()
        };
        assert!(interactor.call(input).expect("ok"));
        assert_eq!(output.success.as_ref().map(|e| e.name.as_str()), Some("剪定"));
    }

    // Ruby: test "calls on_failure with policy_exception when permission is denied"
    #[test]
    fn calls_on_failure_when_permission_denied() {
        let user_id = 10;
        let current = sample_current(99);

        struct DenyGateway {
            current: AgriculturalTaskEntity,
        }

        impl AgriculturalTaskGateway for DenyGateway {
            fn list_user_owned_tasks(
                &self,
                _: i64,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn list_reference_tasks(
                &self,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn list_user_and_reference_tasks(
                &self,
                _: i64,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn find_agricultural_task_show_detail(
                &self,
                _: i64,
            ) -> Result<
                crate::agricultural_task::dtos::AgriculturalTaskShowDetail,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }

            fn find_by_id(
                &self,
                _: i64,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                Ok(self.current.clone())
            }

            fn find_by_reference_and_name(
                &self,
                _: &str,
            ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn find_by_user_id_and_name(
                &self,
                _: i64,
                _: &str,
            ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn create(
                &self,
                _: AttrMap,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }

            fn update(
                &self,
                _: i64,
                _: AttrMap,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                panic!("update should not be called");
            }

            fn within_transaction<F, T>(&self, block: F) -> T
            where
                F: FnOnce() -> T,
            {
                block()
            }

            fn soft_delete_with_undo(
                &self,
                _: &User,
                _: i64,
                _: i64,
                _: &str,
            ) -> Result<
                crate::agricultural_task::gateways::SoftDeleteUndoResult,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }
        }

        let gateway = DenyGateway { current };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = MockUserLookup {
            user: User::new(user_id, false),
        };
        let mut interactor = AgriculturalTaskUpdateInteractor::new(
            &mut output,
            user_id,
            &gateway,
            &NullCropGateways,
            &NullTemplateGateway,
            &StubTranslator,
            &user_lookup,
        );
        let input = AgriculturalTaskUpdateInput {
            id: 5,
            name: Some("x".into()),
            ..Default::default()
        };
        assert!(!interactor.call(input).expect("ok"));
        assert!(matches!(
            output.failure,
            Some(UpdateFailure::Policy(PolicyPermissionDenied))
        ));
    }

    // Ruby: test "一般ユーザーが is_reference を変更しようとすると on_failure"
    #[test]
    fn regular_user_cannot_change_is_reference() {
        let user_id = 10;
        let current = sample_current(user_id);

        struct RefGateway {
            current: AgriculturalTaskEntity,
        }

        impl AgriculturalTaskGateway for RefGateway {
            fn list_user_owned_tasks(
                &self,
                _: i64,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn list_reference_tasks(
                &self,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn list_user_and_reference_tasks(
                &self,
                _: i64,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn find_agricultural_task_show_detail(
                &self,
                _: i64,
            ) -> Result<
                crate::agricultural_task::dtos::AgriculturalTaskShowDetail,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }

            fn find_by_id(
                &self,
                _: i64,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                Ok(self.current.clone())
            }

            fn find_by_reference_and_name(
                &self,
                _: &str,
            ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn find_by_user_id_and_name(
                &self,
                _: i64,
                _: &str,
            ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn create(
                &self,
                _: AttrMap,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }

            fn update(
                &self,
                _: i64,
                _: AttrMap,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                panic!("update should not be called");
            }

            fn within_transaction<F, T>(&self, block: F) -> T
            where
                F: FnOnce() -> T,
            {
                block()
            }

            fn soft_delete_with_undo(
                &self,
                _: &User,
                _: i64,
                _: i64,
                _: &str,
            ) -> Result<
                crate::agricultural_task::gateways::SoftDeleteUndoResult,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }
        }

        let gateway = RefGateway { current };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = MockUserLookup {
            user: User::new(user_id, false),
        };
        let mut interactor = AgriculturalTaskUpdateInteractor::new(
            &mut output,
            user_id,
            &gateway,
            &NullCropGateways,
            &NullTemplateGateway,
            &StubTranslator,
            &user_lookup,
        );
        let input = AgriculturalTaskUpdateInput {
            id: 5,
            is_reference: Some(true),
            ..Default::default()
        };
        assert!(!interactor.call(input).expect("ok"));
        match output.failure {
            Some(UpdateFailure::ReferenceFlag(f)) => {
                assert_eq!(f.message, "agricultural_tasks.flash.reference_flag_admin_only");
                assert_eq!(f.resource_id, 5);
            }
            other => panic!("expected ReferenceFlag, got {other:?}"),
        }
    }

    // Ruby: test "同名がスコープ内に存在すると on_failure（name taken）"
    #[test]
    fn duplicate_name_fails() {
        let user_id = 10;
        let current = sample_current(user_id);
        let duplicate = AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(99),
            user_id: Some(user_id),
            name: "重複名".into(),
            ..Default::default()
        })
        .expect("valid");

        struct DupGateway {
            current: AgriculturalTaskEntity,
            duplicate: AgriculturalTaskEntity,
        }

        impl AgriculturalTaskGateway for DupGateway {
            fn list_user_owned_tasks(
                &self,
                _: i64,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn list_reference_tasks(
                &self,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn list_user_and_reference_tasks(
                &self,
                _: i64,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn find_agricultural_task_show_detail(
                &self,
                _: i64,
            ) -> Result<
                crate::agricultural_task::dtos::AgriculturalTaskShowDetail,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }

            fn find_by_id(
                &self,
                _: i64,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                Ok(self.current.clone())
            }

            fn find_by_reference_and_name(
                &self,
                _: &str,
            ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn find_by_user_id_and_name(
                &self,
                _: i64,
                _: &str,
            ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                Ok(Some(self.duplicate.clone()))
            }

            fn create(
                &self,
                _: AttrMap,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }

            fn update(
                &self,
                _: i64,
                _: AttrMap,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                panic!("update should not be called");
            }

            fn within_transaction<F, T>(&self, block: F) -> T
            where
                F: FnOnce() -> T,
            {
                block()
            }

            fn soft_delete_with_undo(
                &self,
                _: &User,
                _: i64,
                _: i64,
                _: &str,
            ) -> Result<
                crate::agricultural_task::gateways::SoftDeleteUndoResult,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }
        }

        let gateway = DupGateway {
            current,
            duplicate,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = MockUserLookup {
            user: User::new(user_id, false),
        };
        let mut interactor = AgriculturalTaskUpdateInteractor::new(
            &mut output,
            user_id,
            &gateway,
            &NullCropGateways,
            &NullTemplateGateway,
            &StubTranslator,
            &user_lookup,
        );
        let input = AgriculturalTaskUpdateInput {
            id: 5,
            name: Some("重複名".into()),
            ..Default::default()
        };
        assert!(!interactor.call(input).expect("ok"));
        match output.failure {
            Some(UpdateFailure::Error(e)) => {
                assert_eq!(
                    e.message,
                    "activerecord.errors.models.agricultural_task.attributes.name.taken"
                );
            }
            other => panic!("expected Error, got {other:?}"),
        }
    }
}
