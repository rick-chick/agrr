//! Ruby: `Domain::Farm::Interactors::FarmUpdateInteractor`

use crate::farm::calculators::FarmWeatherProgressCalculator;
use crate::farm::dtos::FarmUpdateInput;
use crate::farm::entities::FarmEntity;
use crate::farm::gateways::FarmGateway;
use crate::farm::policies::{FarmCoordinateNormalizationPolicy, FarmReferenceOwnershipPolicy};
use crate::farm::ports::{FarmUpdateOutputPort, UpdateFailure};
use crate::shared::attr::{AttrMap, AttrValue};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::hash::present_attr;
use crate::shared::policies::farm_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;
use crate::shared::type_converters::cast_boolean_attr;

pub struct FarmUpdateInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> FarmUpdateInteractor<'a, G, O, U, T>
where
    G: FarmGateway,
    O: FarmUpdateOutputPort,
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
        input: FarmUpdateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let mut requested = AttrMap::new();
        if let Some(name) = input.name {
            requested.insert("name".into(), AttrValue::from(name.as_str()));
        }
        if let Some(region) = input.region.as_ref() {
            if present_attr(&AttrValue::from(region.as_str())) {
                requested.insert("region".into(), AttrValue::from(region.as_str()));
            }
        }
        if let Some(lat) = input.latitude {
            requested.insert("latitude".into(), AttrValue::Str(lat.to_string()));
        }
        if let Some(lon) = input.longitude {
            requested.insert(
                "longitude".into(),
                AttrValue::Str(
                    FarmCoordinateNormalizationPolicy::normalized_longitude(lon).to_string(),
                ),
            );
        }

        let mut normalized =
            farm_policy::normalize_attrs_for_update(&user, AttrMap::new(), requested.clone());
        let access_filter = farm_policy::record_access_filter(user);

        let current = self.gateway.find_by_id(input.farm_id)?;
        if let Err(policy) =
            reference_record_authorization::assert_edit_allowed(&access_filter, &current)
        {
            self.output_port.on_failure(UpdateFailure::Policy(policy));
            return Ok(());
        }

        let effective_reference = normalized
            .get("is_reference")
            .map(cast_boolean_attr)
            .unwrap_or(current.reference());
        if effective_reference {
            let owner_id = normalized
                .get("user_id")
                .and_then(|v| match v {
                    AttrValue::Int(id) => Some(*id),
                    _ => None,
                })
                .or(current.user_id)
                .unwrap_or(0);
            let owner = self.user_lookup.find(owner_id);
            if !FarmReferenceOwnershipPolicy::reference_farm_user_valid(
                true,
                owner.anonymous,
            ) {
                let opts = TranslateOptions::default();
                let message = self.translator.t(
                    "activerecord.errors.models.farm.attributes.is_reference.reference_only_anonymous",
                    &opts,
                );
                return Err(Box::new(RecordInvalidError::new(Some(message), None)));
            }
        }

        let lat_changed = input.latitude.is_some();
        let lon_changed = input.longitude.is_some();
        if lat_changed || lon_changed {
            let lat = input
                .latitude
                .or(current.latitude)
                .unwrap_or(0.0);
            let lon = input
                .longitude
                .or(current.longitude)
                .unwrap_or(0.0);
            if lat != current.latitude.unwrap_or(0.0) || lon != current.longitude.unwrap_or(0.0) {
                for (k, v) in FarmWeatherProgressCalculator::reset_for_coordinate_change_attrs() {
                    normalized.insert(k, v);
                }
            }
        }

        match self
            .gateway
            .update_for_user(&user, input.farm_id, normalized)
        {
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
        if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
            output_port.on_failure(UpdateFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }
        if err.downcast_ref::<RecordNotFoundError>().is_some()
            || err.downcast_ref::<RecordInvalidError>().is_some()
        {
            output_port.on_failure(UpdateFailure::Error(Error::new(err.to_string())));
            return Ok(());
        }
        Err(err)
    }
}

#[cfg(test)]
mod interactors_farm_update_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/farm/interactors_farm_update_interactor_test.rs"));
}
