//! Ruby: `Domain::Farm::Interactors::FarmUpdateInteractor`

use crate::farm::calculators::FarmWeatherProgressCalculator;
use crate::farm::dtos::{FarmUpdateInput, StartFarmWeatherDataFetchInput};
use crate::farm::entities::FarmEntity;
use crate::farm::gateways::FarmGateway;
use crate::farm::interactors::StartFarmWeatherDataFetchInteractor;
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
use crate::shared::ports::{ClockPort, FetchWeatherDataEnqueuePort};
use crate::shared::reference_record_authorization;
use crate::shared::type_converters::cast_boolean_attr;

pub struct FarmUpdateInteractor<'a, G, O, U, T, E, C> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
    weather_fetch_enqueue: &'a E,
    clock: &'a C,
}

impl<'a, G, O, U, T, E, C> FarmUpdateInteractor<'a, G, O, U, T, E, C>
where
    G: FarmGateway,
    O: FarmUpdateOutputPort,
    U: UserLookupGateway,
    T: TranslatorPort,
    E: FetchWeatherDataEnqueuePort,
    C: ClockPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        translator: &'a T,
        user_lookup: &'a U,
        weather_fetch_enqueue: &'a E,
        clock: &'a C,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            translator,
            user_lookup,
            weather_fetch_enqueue,
            clock,
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
        let coordinates_changed = if lat_changed || lon_changed {
            let lat = input
                .latitude
                .or(current.latitude)
                .unwrap_or(0.0);
            let lon = input
                .longitude
                .or(current.longitude)
                .unwrap_or(0.0);
            lat != current.latitude.unwrap_or(0.0) || lon != current.longitude.unwrap_or(0.0)
        } else {
            false
        };
        let was_failed = current.weather_data_status.as_deref() == Some("failed");
        let should_start_weather_fetch = coordinates_changed || was_failed;

        if coordinates_changed {
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
                let response_entity = if should_start_weather_fetch {
                    Self::start_weather_fetch_if_applicable(
                        self.gateway,
                        self.weather_fetch_enqueue,
                        self.clock,
                        entity,
                    )?
                } else {
                    entity
                };
                self.output_port.on_success(response_entity);
                Ok(())
            }
            Err(err) => Self::handle_gateway_error(&mut self.output_port, err),
        }
    }

    fn start_weather_fetch_if_applicable(
        gateway: &G,
        weather_fetch_enqueue: &E,
        clock: &C,
        entity: FarmEntity,
    ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
        if entity.is_reference || !entity.has_coordinates() {
            return Ok(entity);
        }

        let interactor =
            StartFarmWeatherDataFetchInteractor::new(gateway, weather_fetch_enqueue);
        let input = StartFarmWeatherDataFetchInput {
            farm_id: entity.id,
            as_of: clock.today(),
        };
        match interactor.call(input)? {
            Some(_) => gateway.find_by_id(entity.id),
            None => Ok(entity),
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
