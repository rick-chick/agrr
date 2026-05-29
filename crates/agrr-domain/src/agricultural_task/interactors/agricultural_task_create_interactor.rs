//! Ruby: `Domain::AgriculturalTask::Interactors::AgriculturalTaskCreateInteractor`

use crate::agricultural_task::dtos::AgriculturalTaskCreateInput;
use crate::agricultural_task::entities::AgriculturalTaskEntity;
use crate::agricultural_task::gateways::AgriculturalTaskGateway;
use crate::agricultural_task::interactors::attr_helpers::{attr_is_reference, attr_user_id};
use crate::agricultural_task::ports::AgriculturalTaskCreateOutputPort;
use crate::shared::attr::{attr_map_from_pairs, AttrValue};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::ports::translator_port::TranslateOptions;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::agricultural_task_policy;
use crate::shared::policies::referencable_resource_policy::{
    duplicate_name_record, reference_assignment_allowed, reference_record_user_id_valid,
};
use crate::shared::ports::TranslatorPort;

pub struct AgriculturalTaskCreateInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> AgriculturalTaskCreateInteractor<'a, G, O, U, T>
where
    G: AgriculturalTaskGateway,
    O: AgriculturalTaskCreateOutputPort,
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
        input: AgriculturalTaskCreateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let is_reference = input.is_reference.unwrap_or(false);
        if !reference_assignment_allowed(&user, is_reference) {
            let message = self.translator.t(
                "agricultural_tasks.flash.reference_only_admin",
                &TranslateOptions::default(),
            );
            self.output_port.on_failure(Error::new(message));
            return Ok(());
        }

        let attrs = agricultural_task_policy::normalize_attrs_for_create(
            &user,
            attr_map_from_pairs([
                ("name", AttrValue::from(input.name.as_str())),
                (
                    "description",
                    input
                        .description
                        .as_deref()
                        .map(AttrValue::from)
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "time_per_sqm",
                    input
                        .time_per_sqm
                        .map(|v| AttrValue::Str(v.to_string()))
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "weather_dependency",
                    input
                        .weather_dependency
                        .as_deref()
                        .map(AttrValue::from)
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "required_tools",
                    AttrValue::Str(input.required_tools.join(",")),
                ),
                (
                    "skill_level",
                    input
                        .skill_level
                        .as_deref()
                        .map(AttrValue::from)
                        .unwrap_or(AttrValue::Null),
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
                    "task_type",
                    input
                        .task_type
                        .as_deref()
                        .map(AttrValue::from)
                        .unwrap_or(AttrValue::Null),
                ),
                ("is_reference", AttrValue::Bool(is_reference)),
            ]),
        );

        if !reference_record_user_id_valid(attr_is_reference(&attrs), attr_user_id(&attrs)) {
            let message = self.translator.t(
                "activerecord.errors.models.agricultural_task.attributes.user.blank",
                &TranslateOptions::default(),
            );
            self.output_port.on_failure(Error::new(message));
            return Ok(());
        }

        let existing = self.find_existing_by_name(&attrs)?;
        if duplicate_name_record(existing.and_then(|e| e.id), None) {
            let message = self.translator.t(
                "activerecord.errors.models.agricultural_task.attributes.name.taken",
                &TranslateOptions::default(),
            );
            self.output_port.on_failure(Error::new(message));
            return Ok(());
        }

        match self.gateway.create(attrs) {
            Ok(entity) => {
                self.output_port.on_success(entity);
                Ok(())
            }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(record_invalid) => {
                    let message = record_invalid.to_string();
                    self.output_port.on_failure(Error::new(message));
                    Ok(())
                }
                Err(err) => Err(err),
            },
        }
    }

    fn find_existing_by_name(
        &self,
        attrs: &crate::shared::attr::AttrMap,
    ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
        let name = attrs
            .get("name")
            .and_then(|v| match v {
                AttrValue::Str(s) => Some(s.as_str()),
                _ => None,
            })
            .unwrap_or("");
        if attr_is_reference(attrs) {
            self.gateway.find_by_reference_and_name(name)
        } else {
            self.gateway.find_by_user_id_and_name(
                attr_user_id(attrs).unwrap_or(self.user_id),
                name,
            )
        }
    }
}

#[cfg(test)]
mod interactors_agricultural_task_create_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/agricultural_task/interactors_agricultural_task_create_interactor_test.rs"));
}
