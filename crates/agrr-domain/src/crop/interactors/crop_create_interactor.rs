//! Ruby: `Domain::Crop::Interactors::CropCreateInteractor`

use crate::crop::dtos::{CropCreateInput, CropCreateLimitExceededFailure};
use crate::crop::gateways::CropGateway;
use crate::crop::policies::crop_create_limit_policy;
use crate::crop::ports::{CreateFailure, CropCreateOutputPort};
use crate::organization::gateways::PersonalOrganizationGateway;
use crate::shared::attr::{attr_map_from_pairs, AttrValue};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::{UserLookupGateway, UserOrganizationScopeGateway};
use crate::shared::org_scope::member_organization_ids;
use crate::shared::policies::{crop_policy, referencable_resource_policy};
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};

pub struct CropCreateInteractor<'a, G, O, U, T, S, P> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
    scope_gateway: &'a S,
    personal_org_gateway: &'a P,
}

impl<'a, G, O, U, T, S, P> CropCreateInteractor<'a, G, O, U, T, S, P>
where
    G: CropGateway,
    O: CropCreateOutputPort,
    U: UserLookupGateway,
    T: TranslatorPort,
    S: UserOrganizationScopeGateway,
    P: PersonalOrganizationGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        translator: &'a T,
        user_lookup: &'a U,
        scope_gateway: &'a S,
        personal_org_gateway: &'a P,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            translator,
            user_lookup,
            scope_gateway,
            personal_org_gateway,
        }
    }

    pub fn call(
        &mut self,
        input: CropCreateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let org_ids = member_organization_ids(self.scope_gateway, user.id)?;
        let organization_id = if let Some(&id) = org_ids.first() {
            id
        } else {
            self.personal_org_gateway
                .ensure_personal_organization(user.id, "", "")?
        };
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
            attrs.insert("organization_id".into(), AttrValue::Int(organization_id));
            let existing_count = self
                .gateway
                .count_non_reference_crops_for_organization(organization_id)?;
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
mod interactors_crop_create_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_create_interactor_test.rs"));
}
