//! Ruby: `Domain::WeatherData::Interactors::FarmWeatherDataAccessInteractor`


use crate::shared::ports::ClockPort;
use crate::weather_data::dtos::{
    FarmWeatherDataAccessContext, FarmWeatherDataAccessInput, WeatherData,
};
use crate::weather_data::gateways::{WeatherDataFarmGateway, WeatherDataGateway};
use crate::weather_data::helpers::{parse_iso_date, subtract_months};
use crate::weather_data::ports::{
    FarmWeatherDataAccessOutputPort, FarmWeatherFarmSummary, FarmWeatherIndexRow,
    FarmWeatherPeriod, FarmWeatherPredictionPayloadParsePort,
    PredictWeatherStandaloneEnqueuePort,
};

const STALE_AFTER_SECONDS: i64 = 24 * 60 * 60;

/// Ruby: `Domain::WeatherData::Interactors::FarmWeatherDataAccessInteractor`
pub struct FarmWeatherDataAccessInteractor<'a, O> {
    output_port: &'a mut O,
    farm_gateway: &'a dyn WeatherDataFarmGateway,
    weather_data_gateway: &'a dyn WeatherDataGateway,
    enqueue_port: &'a dyn PredictWeatherStandaloneEnqueuePort,
    prediction_payload_parse: &'a dyn FarmWeatherPredictionPayloadParsePort,
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
        prediction_payload_parse: &'a dyn FarmWeatherPredictionPayloadParsePort,
        clock: &'a dyn ClockPort,
    ) -> Self {
        Self {
            output_port,
            farm_gateway,
            weather_data_gateway,
            enqueue_port,
            prediction_payload_parse,
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
        let weather_data_dtos = self.weather_data_gateway.weather_data_for_period(
            wl_id,
            start_date,
            end_date,
        );

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
        if let Some(ref prediction_hash) = ctx.predicted_weather_data {
            if prediction_hash
                .get("data")
                .and_then(|v| v.as_array())
                .is_some_and(|a| !a.is_empty())
            {
                let predicted_at = self.prediction_payload_parse.predicted_at_from_payload(
                    prediction_hash
                        .get("predicted_at")
                        .and_then(|v| v.as_str()),
                );
                let prediction_start = self.prediction_payload_parse.prediction_start_date_from_payload(
                    prediction_hash
                        .get("prediction_start_date")
                        .and_then(|v| v.as_str()),
                );

                let is_outdated = predicted_at.is_none()
                    || (self.clock.now() - predicted_at.expect("present"))
                        .whole_seconds()
                        > STALE_AFTER_SECONDS
                    || prediction_start.is_none()
                    || prediction_start.expect("present") < self.clock.today();

                if !is_outdated {
                    let filtered_data: Vec<FarmWeatherIndexRow> = prediction_hash
                        .get("data")
                        .and_then(|v| v.as_array())
                        .map(|arr| {
                            arr.iter()
                                .filter_map(|datum| map_prediction_row(datum))
                                .collect()
                        })
                        .unwrap_or_default();

                    self.output_port.on_prediction_cached_success(
                        FarmWeatherFarmSummary {
                            id: ctx.farm_id,
                            name: ctx.display_name.clone(),
                            latitude: ctx.latitude,
                            longitude: ctx.longitude,
                        },
                        crate::weather_data::ports::FarmWeatherPredictionPeriod {
                            start_date: prediction_hash
                                .get("prediction_start_date")
                                .and_then(|v| v.as_str())
                                .unwrap_or_default()
                                .to_string(),
                            end_date: prediction_hash
                                .get("prediction_end_date")
                                .and_then(|v| v.as_str())
                                .unwrap_or_default()
                                .to_string(),
                        },
                        true,
                        prediction_hash
                            .get("predicted_at")
                            .and_then(|v| v.as_str())
                            .map(String::from),
                        prediction_hash
                            .get("model")
                            .and_then(|v| v.as_str())
                            .map(String::from),
                        filtered_data,
                    );
                    return;
                }

                let _ = self
                    .farm_gateway
                    .update_predicted_weather_data(ctx.farm_id, None);
            }
        }

        if ctx.weather_location_id.is_none() {
            self.output_port.on_no_weather_location();
            return;
        }

        let wl_id = ctx.weather_location_id.expect("checked");
        let end_date = self.clock.today();
        let start_date = subtract_months(end_date, 24);
        let required_days = (end_date - start_date).whole_days() + 1;
        let historical_data_count = self.weather_data_gateway.historical_data_count(
            wl_id,
            start_date,
            end_date,
        );

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

fn map_prediction_row(datum: &serde_json::Value) -> Option<FarmWeatherIndexRow> {
    let tmax = datum.get("temperature_max")?.as_f64()?;
    let tmin = datum.get("temperature_min")?.as_f64()?;
    let temp_mean = datum
        .get("temperature_mean")
        .and_then(|v| v.as_f64())
        .unwrap_or((tmax + tmin) / 2.0);
    let date_str = datum.get("date").and_then(|v| v.as_str())?;
    let date = parse_iso_date(date_str)?;
    Some(FarmWeatherIndexRow {
        date,
        temperature_max: tmax,
        temperature_min: tmin,
        temperature_mean: temp_mean,
        precipitation: datum
            .get("precipitation")
            .and_then(|v| v.as_f64())
            .unwrap_or(0.0),
    })
}

#[cfg(test)]
mod interactors_farm_weather_data_access_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/weather_data/interactors_farm_weather_data_access_interactor_test.rs"));
}
