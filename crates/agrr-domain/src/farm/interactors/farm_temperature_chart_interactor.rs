//! Observed temperature chart for farm detail (no prediction / GDD).

use crate::farm::dtos::{
    FarmTemperatureChartDataQuality, FarmTemperatureChartInput, FarmTemperatureChartOutput,
    FarmTemperatureChartPoint,
};
use crate::farm::gateways::FarmGateway;
use crate::farm::ports::{
    FarmTemperatureChartFailure, FarmTemperatureChartOutputPort,
};
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::farm_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::ClockPort;
use crate::shared::reference_record_authorization;
use crate::weather_data::dtos::WeatherData;
use crate::weather_data::gateways::WeatherDataGateway;
use time::Duration;

pub fn normalize_period(period: &str) -> (&'static str, i64) {
    match period {
        "30d" => ("30d", 30),
        "90d" => ("90d", 90),
        "180d" => ("180d", 180),
        "365d" => ("365d", 365),
        _ => ("90d", 90),
    }
}

pub struct FarmTemperatureChartInteractor<'a, G, W, O, U> {
    output_port: &'a mut O,
    farm_gateway: &'a G,
    weather_data_gateway: &'a W,
    user_lookup: &'a U,
    clock: &'a dyn ClockPort,
}

impl<'a, G, W, O, U> FarmTemperatureChartInteractor<'a, G, W, O, U>
where
    G: FarmGateway,
    W: WeatherDataGateway,
    O: FarmTemperatureChartOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        farm_gateway: &'a G,
        weather_data_gateway: &'a W,
        user_lookup: &'a U,
        clock: &'a dyn ClockPort,
    ) -> Self {
        Self {
            output_port,
            farm_gateway,
            weather_data_gateway,
            user_lookup,
            clock,
        }
    }

    pub fn call(
        &mut self,
        input: FarmTemperatureChartInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(input.user_id);
        let access_filter = farm_policy::record_access_filter(user);

        let farm_entity = match self.farm_gateway.find_by_id(input.farm_id) {
            Ok(entity) => entity,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(FarmTemperatureChartFailure::NotFound);
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        if let Err(PolicyPermissionDenied) =
            reference_record_authorization::assert_view_allowed(&access_filter, &farm_entity)
        {
            self.output_port.on_failure(FarmTemperatureChartFailure::NotFound);
            return Ok(());
        }

        let status = farm_entity.weather_data_status.as_deref().unwrap_or("pending");
        if status != "completed" {
            self.output_port.on_failure(FarmTemperatureChartFailure::WeatherNotReady {
                status: status.to_string(),
                progress: farm_entity.weather_data_progress(),
            });
            return Ok(());
        }

        let weather_location_id = match farm_entity.weather_location_id {
            Some(id) => id,
            None => {
                self.output_port
                    .on_failure(FarmTemperatureChartFailure::NoWeatherLocation);
                return Ok(());
            }
        };

        let (period_label, period_days) = normalize_period(&input.period);
        let end_date = self.clock.today();
        let start_date = end_date - Duration::days(period_days - 1);

        let weather_rows = match self.weather_data_gateway.weather_data_for_period(
            weather_location_id,
            start_date,
            end_date,
        ) {
            Ok(rows) => rows,
            Err(_) => {
                self.output_port
                    .on_failure(FarmTemperatureChartFailure::StorageUnavailable);
                return Ok(());
            }
        };

        let points: Vec<FarmTemperatureChartPoint> = weather_rows
            .iter()
            .filter_map(map_chart_point)
            .collect();
        let present_days = points.len() as i64;
        let expected_days = period_days;
        let missing_days = (expected_days - present_days).max(0);

        self.output_port.on_success(FarmTemperatureChartOutput {
            farm_id: input.farm_id,
            period: period_label.to_string(),
            start_date,
            end_date,
            observed_only: true,
            data_quality: FarmTemperatureChartDataQuality {
                expected_days,
                present_days,
                missing_days,
            },
            points,
        });
        Ok(())
    }
}

fn map_chart_point(dto: &WeatherData) -> Option<FarmTemperatureChartPoint> {
    let tmax = dto.temperature_max?;
    let tmin = dto.temperature_min?;
    let temp_mean = dto
        .temperature_mean
        .unwrap_or((tmax + tmin) / 2.0);
    Some(FarmTemperatureChartPoint {
        date: dto.date,
        temperature_min: Some(tmin),
        temperature_mean: Some(temp_mean),
        temperature_max: Some(tmax),
    })
}

#[cfg(test)]
mod interactors_farm_temperature_chart_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/farm/interactors_farm_temperature_chart_interactor_test.rs"
    ));
}
