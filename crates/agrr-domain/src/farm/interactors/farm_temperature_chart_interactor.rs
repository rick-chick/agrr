//! Ruby: `Domain::Farm::Interactors::FarmTemperatureChartInteractor`

use time::Duration;

use crate::farm::dtos::{
    FarmTemperatureChartDataQuality, FarmTemperatureChartInput, FarmTemperatureChartOutput,
    FarmTemperatureChartPoint,
};
use crate::farm::entities::FarmEntity;
use crate::farm::gateways::{FarmGateway, FarmTemperatureChartWeatherGateway};
use crate::farm::policies::farm_temperature_chart_period_policy::{
    normalize_period, period_days,
};
use crate::farm::ports::{FarmTemperatureChartOutputPort, TemperatureChartFailure};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::farm_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::ClockPort;
use crate::shared::reference_record_authorization;

pub struct FarmTemperatureChartInteractor<'a, G, W, O, U, C> {
    output_port: &'a mut O,
    farm_gateway: &'a G,
    weather_gateway: &'a W,
    clock: &'a C,
    user_id: i64,
    user_lookup: &'a U,
}

impl<'a, G, W, O, U, C> FarmTemperatureChartInteractor<'a, G, W, O, U, C>
where
    G: FarmGateway,
    W: FarmTemperatureChartWeatherGateway,
    O: FarmTemperatureChartOutputPort,
    U: UserLookupGateway,
    C: ClockPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        farm_gateway: &'a G,
        weather_gateway: &'a W,
        clock: &'a C,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            farm_gateway,
            weather_gateway,
            clock,
            user_id,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        input: FarmTemperatureChartInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = farm_policy::record_access_filter(user);

        let farm_entity = match self.farm_gateway.find_by_id(input.farm_id) {
            Ok(entity) => entity,
            Err(err) => return Self::handle_gateway_error(&mut self.output_port, err),
        };

        if let Err(policy) =
            reference_record_authorization::assert_view_allowed(&access_filter, &farm_entity)
        {
            self.output_port
                .on_failure(TemperatureChartFailure::Policy(policy));
            return Ok(());
        }

        if !Self::weather_data_ready(&farm_entity) {
            self.output_port.on_failure(TemperatureChartFailure::WeatherNotReady {
                status: farm_entity
                    .weather_data_status
                    .clone()
                    .unwrap_or_else(|| "pending".into()),
                progress: farm_entity.weather_data_progress(),
            });
            return Ok(());
        }

        let weather_location_id = match farm_entity.weather_location_id {
            Some(id) => id,
            None => {
                self.output_port.on_failure(
                    TemperatureChartFailure::MissingWeatherLocation(Error::new(
                        "weather_location_missing",
                    )),
                );
                return Ok(());
            }
        };

        let period = normalize_period(input.period.as_deref());
        let days = period_days(period);
        let end_date = self.clock.today();
        let start_date = end_date
            .checked_sub(Duration::days(days.saturating_sub(1)))
            .unwrap_or(end_date);

        let weather_rows = match self.weather_gateway.weather_data_for_period(
            weather_location_id,
            start_date,
            end_date,
        ) {
            Ok(rows) => rows,
            Err(err) => {
                self.output_port
                    .on_failure(TemperatureChartFailure::Storage(Error::new(err.to_string())));
                return Ok(());
            }
        };

        let points: Vec<FarmTemperatureChartPoint> = weather_rows
            .into_iter()
            .map(|row| FarmTemperatureChartPoint {
                date: row.date,
                temperature_min: row.temperature_min,
                temperature_mean: row.temperature_mean,
                temperature_max: row.temperature_max,
            })
            .collect();

        let present_days = points.len() as i64;
        let missing_days = (days - present_days).max(0);

        self.output_port.on_success(FarmTemperatureChartOutput {
            farm_id: input.farm_id,
            period: period.to_string(),
            start_date,
            end_date,
            observed_only: true,
            data_quality: FarmTemperatureChartDataQuality {
                expected_days: days,
                present_days,
                missing_days,
            },
            points,
        });

        Ok(())
    }

    fn weather_data_ready(farm: &FarmEntity) -> bool {
        farm.weather_data_status.as_deref() == Some("completed")
    }

    fn handle_gateway_error(
        output_port: &mut O,
        err: Box<dyn std::error::Error + Send + Sync>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
            output_port.on_failure(TemperatureChartFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }
        if err.downcast_ref::<RecordNotFoundError>().is_some()
            || err.downcast_ref::<RecordInvalidError>().is_some()
        {
            output_port.on_failure(TemperatureChartFailure::NotFound(Error::new(err.to_string())));
            return Ok(());
        }
        Err(err)
    }
}

#[cfg(test)]
mod interactors_farm_temperature_chart_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/farm/interactors_farm_temperature_chart_interactor_test.rs"
    ));
}
