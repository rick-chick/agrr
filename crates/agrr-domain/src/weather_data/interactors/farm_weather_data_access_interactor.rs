//! Ruby: `Domain::WeatherData::Interactors::FarmWeatherDataAccessInteractor`


use crate::shared::ports::ClockPort;
use crate::weather_data::dtos::{
    FarmWeatherDataAccessContext, FarmWeatherDataAccessInput, WeatherData,
};
use crate::weather_data::gateways::{WeatherDataFarmGateway, WeatherDataGateway};
use crate::weather_data::helpers::subtract_months;
use crate::weather_data::ports::{
    FarmWeatherDataAccessOutputPort, FarmWeatherFarmSummary, FarmWeatherIndexRow,
    FarmWeatherPeriod, PredictWeatherStandaloneEnqueuePort,
};

/// Ruby: `Domain::WeatherData::Interactors::FarmWeatherDataAccessInteractor`
pub struct FarmWeatherDataAccessInteractor<'a, O> {
    output_port: &'a mut O,
    farm_gateway: &'a dyn WeatherDataFarmGateway,
    weather_data_gateway: &'a dyn WeatherDataGateway,
    enqueue_port: &'a dyn PredictWeatherStandaloneEnqueuePort,
    clock: &'a dyn ClockPort,
}

impl<'a, O> FarmWeatherDataAccessInteractor<'a, O>
where
    O: FarmWeatherDataAccessOutputPort,
{
    pub fn new(
        output_port: &'a mut O,
        farm_gateway: &'a dyn WeatherDataFarmGateway,
        weather_data_gateway: &'a dyn WeatherDataGateway,
        enqueue_port: &'a dyn PredictWeatherStandaloneEnqueuePort,
        clock: &'a dyn ClockPort,
    ) -> Self {
        Self {
            output_port,
            farm_gateway,
            weather_data_gateway,
            enqueue_port,
            clock,
        }
    }

    pub fn call(&mut self, input: FarmWeatherDataAccessInput) {
        let ctx = if input.is_admin {
            self.farm_gateway
                .farm_weather_data_access_context_for_admin_lookup(input.farm_id)
        } else {
            self.farm_gateway
                .farm_weather_data_access_context_for_owned_farm(input.user_id, input.farm_id)
        };

        let Some(ctx) = ctx else {
            self.output_port.on_farm_not_found();
            return;
        };

        if input.predict {
            self.predict_flow(&ctx);
        } else {
            self.index_flow(&ctx, &input);
        }
    }

    fn index_flow(&mut self, ctx: &FarmWeatherDataAccessContext, input: &FarmWeatherDataAccessInput) {
        let end_date = input.end_date.unwrap_or_else(|| self.clock.today());
        let start_date = input.start_date.unwrap_or_else(|| subtract_months(end_date, 12));

        if ctx.weather_location_id.is_none() {
            self.output_port.on_no_weather_location();
            return;
        }

        let wl_id = ctx.weather_location_id.expect("checked");
        let weather_data_dtos = match self.weather_data_gateway.weather_data_for_period(
            wl_id,
            start_date,
            end_date,
        ) {
            Ok(d) => d,
            Err(_) => {
                self.output_port.on_weather_data_storage_unavailable();
                return;
            }
        };

        let filtered: Vec<FarmWeatherIndexRow> = weather_data_dtos
            .into_iter()
            .filter_map(|dto| map_index_row(&dto))
            .collect();

        self.output_port.on_index_success(
            FarmWeatherFarmSummary {
                id: ctx.farm_id,
                name: ctx.display_name.clone(),
                latitude: ctx.latitude,
                longitude: ctx.longitude,
            },
            FarmWeatherPeriod {
                start_date,
                end_date,
            },
            filtered,
        );
    }

    fn predict_flow(&mut self, ctx: &FarmWeatherDataAccessContext) {
        if ctx.weather_location_id.is_none() {
            self.output_port.on_no_weather_location();
            return;
        }

        let wl_id = ctx.weather_location_id.expect("checked");
        let end_date = self.clock.today();
        let start_date = subtract_months(end_date, 24);
        let required_days = (end_date - start_date).whole_days() + 1;
        let historical_data_count = match self.weather_data_gateway.historical_data_count(
            wl_id,
            start_date,
            end_date,
        ) {
            Ok(c) => c,
            Err(_) => {
                self.output_port.on_weather_data_storage_unavailable();
                return;
            }
        };

        if historical_data_count < required_days {
            self.output_port.on_insufficient_historical_data();
            return;
        }

        let result = self.enqueue_port.enqueue_predict_weather_standalone(
            ctx.farm_id,
            None,
            "lightgbm",
            None,
            None,
            None,
        );

        if !result.ok {
            self.output_port.on_enqueue_failed(
                result.error_message.unwrap_or_else(|| "enqueue failed".to_string()),
            );
            return;
        }

        self.output_port
            .on_prediction_queued(ctx.farm_id, ctx.display_name.clone());
    }
}

fn map_index_row(dto: &WeatherData) -> Option<FarmWeatherIndexRow> {
    let tmax = dto.temperature_max?;
    let tmin = dto.temperature_min?;
    let temp_mean = dto
        .temperature_mean
        .unwrap_or((tmax + tmin) / 2.0);
    Some(FarmWeatherIndexRow {
        date: dto.date,
        temperature_max: tmax,
        temperature_min: tmin,
        temperature_mean: temp_mean,
        precipitation: dto.precipitation.unwrap_or(0.0),
    })
}

#[cfg(test)]
mod interactors_farm_weather_data_access_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/weather_data/interactors_farm_weather_data_access_interactor_test.rs"));
}
