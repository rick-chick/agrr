//! Ruby: `Domain::Farm::Interactors::FarmCreateInteractor`

use crate::farm::dtos::{FarmCreateInput, FarmCreateLimitExceededFailure};
use crate::farm::entities::FarmEntity;
use crate::farm::gateways::FarmGateway;
use crate::farm::policies::{FarmCoordinateNormalizationPolicy, FarmCreateLimitPolicy};
use crate::farm::ports::{CreateFailure, FarmCreateOutputPort};
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::farm_policy;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};

pub struct FarmCreateInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> FarmCreateInteractor<'a, G, O, U, T>
where
    G: FarmGateway,
    O: FarmCreateOutputPort,
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
        input: FarmCreateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let mut attrs = farm_policy::normalize_attrs_for_create(
            &user,
            attr_map_from_pairs([
                ("name", AttrValue::from(input.name.as_str())),
                (
                    "region",
                    input
                        .region
                        .as_deref()
                        .map(AttrValue::from)
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "latitude",
                    optional_float_attr(input.latitude),
                ),
                (
                    "longitude",
                    optional_float_attr(input.longitude),
                ),
            ]),
        );

        if let Some(AttrValue::Str(lon)) = attrs.get("longitude").cloned() {
            if let Ok(lon_f) = lon.parse::<f64>() {
                attrs.insert(
                    "longitude".into(),
                    AttrValue::Str(
                        FarmCoordinateNormalizationPolicy::normalized_longitude(lon_f)
                            .to_string(),
                    ),
                );
            }
        } else if let Some(AttrValue::Int(lon)) = attrs.get("longitude").cloned() {
            attrs.insert(
                "longitude".into(),
                AttrValue::Str(
                    FarmCoordinateNormalizationPolicy::normalized_longitude(lon as f64)
                        .to_string(),
                ),
            );
        }

        let existing_count = self.gateway.count_user_owned_non_reference_farms(user.id)?;
        if FarmCreateLimitPolicy::limit_exceeded(existing_count) {
            let opts = TranslateOptions::default();
            let message = self.translator.t(
                "activerecord.errors.models.farm.attributes.user.farm_limit_exceeded",
                &opts,
            );
            self.output_port.on_failure(CreateFailure::LimitExceeded(
                FarmCreateLimitExceededFailure::new(message),
            ));
            return Ok(());
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
mod interactors_farm_create_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/farm/interactors_farm_create_interactor_test.rs"));
}
