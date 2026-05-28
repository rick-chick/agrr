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
mod tests {
    use super::*;
    use crate::farm::dtos::{FarmDeleteUsage, FarmDetailOutput};
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
        success: Option<FarmEntity>,
        failure: Option<CreateFailure>,
    }

    impl FarmCreateOutputPort for SpyOutput {
        fn on_success(&mut self, entity: FarmEntity) {
            self.success = Some(entity);
        }
        fn on_failure(&mut self, error: CreateFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_farm() -> FarmEntity {
        FarmEntity {
            id: 99,
            name: "新規農場".into(),
            latitude: Some(35.0),
            longitude: Some(135.0),
            region: None,
            user_id: Some(10),
            created_at: None,
            updated_at: None,
            is_reference: false,
            weather_data_status: None,
            weather_data_fetched_years: None,
            weather_data_total_years: None,
            weather_data_last_error: None,
            weather_location_id: None,
            last_broadcast_at: None,
        }
    }

    struct UnderLimitGateway {
        count: i32,
        entity: FarmEntity,
    }

    struct AtLimitGateway;

    impl FarmGateway for UnderLimitGateway {
        fn list_user_owned_farms(
            &self,
            _: i64,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_user_and_reference_farms(
            &self,
            _: i64,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_reference_farms(
            &self,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update_weather_progress(
            &self,
            _: i64,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_reference_farms_for_region(
            &self,
            _: &str,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn count_user_owned_non_reference_farms(
            &self,
            _: i64,
        ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.count)
        }

        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.entity.clone())
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn farm_detail_with_fields(
            &self,
            _: i64,
        ) -> Result<FarmDetailOutput, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<FarmDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &str,
        ) -> Result<
            crate::farm::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
    }

    impl FarmGateway for AtLimitGateway {
        fn list_user_owned_farms(
            &self,
            _: i64,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_user_and_reference_farms(
            &self,
            _: i64,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_reference_farms(
            &self,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update_weather_progress(
            &self,
            _: i64,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_reference_farms_for_region(
            &self,
            _: &str,
        ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn count_user_owned_non_reference_farms(
            &self,
            _: i64,
        ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            Ok(4)
        }

        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn farm_detail_with_fields(
            &self,
            _: i64,
        ) -> Result<FarmDetailOutput, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<FarmDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &str,
        ) -> Result<
            crate::farm::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
    }

    // Ruby: test "calls on_success when under farm limit"
    #[test]
    fn calls_on_success_when_under_farm_limit() {
        let entity = sample_farm();
        let gateway = UnderLimitGateway {
            count: 3,
            entity: entity.clone(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(10, false));
        let mut interactor = FarmCreateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &user_lookup,
        );
        interactor
            .call(FarmCreateInput::new(
                "新規農場",
                None,
                Some(35.0),
                Some(135.0),
            ))
            .unwrap();
        assert_eq!(output.success, Some(entity));
    }

    // Ruby: test "calls on_failure with limit exceeded dto when at farm limit"
    #[test]
    fn calls_on_failure_with_limit_exceeded_when_at_farm_limit() {
        let gateway = AtLimitGateway;
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = StubLookup(User::new(10, false));
        let mut interactor = FarmCreateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &user_lookup,
        );
        interactor
            .call(FarmCreateInput::new(
                "5件目",
                None,
                Some(35.0),
                Some(135.0),
            ))
            .unwrap();
        match output.failure {
            Some(CreateFailure::LimitExceeded(dto)) => {
                assert_eq!(
                    dto.message,
                    "t:activerecord.errors.models.farm.attributes.user.farm_limit_exceeded"
                );
            }
            other => panic!("expected LimitExceeded failure, got {other:?}"),
        }
    }
}
