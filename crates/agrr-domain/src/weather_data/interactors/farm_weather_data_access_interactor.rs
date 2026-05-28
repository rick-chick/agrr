//! Ruby: `Domain::WeatherData::Interactors::FarmWeatherDataAccessInteractor`

use time::Date;

use crate::shared::ports::{ClockPort, LoggerPort};
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
    logger: &'a dyn LoggerPort,
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
        logger: &'a dyn LoggerPort,
        clock: &'a dyn ClockPort,
    ) -> Self {
        Self {
            output_port,
            farm_gateway,
            weather_data_gateway,
            enqueue_port,
            prediction_payload_parse,
            logger,
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
mod tests {
    use super::*;
    use crate::weather_data::ports::{
        FarmWeatherDataAccessOutputPort, FarmWeatherFarmSummary, FarmWeatherIndexRow,
        FarmWeatherPeriod, FarmWeatherPredictionPeriod, PredictWeatherStandaloneEnqueueResult,
    };
    use std::sync::{Arc, Mutex};
    use time::{Month, OffsetDateTime, Time};

    struct RecordingOutputPort {
        calls: Arc<Mutex<Vec<String>>>,
        last_index: Arc<Mutex<Option<FarmWeatherIndexRow>>>,
    }

    impl FarmWeatherDataAccessOutputPort for RecordingOutputPort {
        fn on_index_success(
            &mut self,
            _: FarmWeatherFarmSummary,
            _: FarmWeatherPeriod,
            data: Vec<FarmWeatherIndexRow>,
        ) {
            self.calls.lock().expect("lock").push("index_success".into());
            if let Some(row) = data.into_iter().next() {
                *self.last_index.lock().expect("lock") = Some(row);
            }
        }

        fn on_prediction_cached_success(
            &mut self,
            _: FarmWeatherFarmSummary,
            _: FarmWeatherPredictionPeriod,
            _: bool,
            _: Option<String>,
            _: Option<String>,
            _: Vec<FarmWeatherIndexRow>,
        ) {
        }

        fn on_prediction_queued(&mut self, _: i64, _: String) {}
        fn on_farm_not_found(&mut self) {
            self.calls.lock().expect("lock").push("farm_not_found".into());
        }
        fn on_no_weather_location(&mut self) {}
        fn on_insufficient_historical_data(&mut self) {}
        fn on_enqueue_failed(&mut self, _: String) {}
    }

    struct FakeFarmGateway {
        ctx: Option<FarmWeatherDataAccessContext>,
    }

    impl WeatherDataFarmGateway for FakeFarmGateway {
        fn farm_weather_data_access_context_for_owned_farm(
            &self,
            _: i64,
            _: i64,
        ) -> Option<FarmWeatherDataAccessContext> {
            self.ctx.clone()
        }

        fn farm_weather_data_access_context_for_admin_lookup(
            &self,
            _: i64,
        ) -> Option<FarmWeatherDataAccessContext> {
            self.ctx.clone()
        }

        fn update_predicted_weather_data(
            &self,
            _: i64,
            _: Option<serde_json::Value>,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<crate::weather_data::gateways::FetchWeatherFarmEntity, crate::shared::exceptions::RecordNotFoundError>
        {
            Err(crate::shared::exceptions::RecordNotFoundError)
        }

        fn update_weather_location_id(
            &self,
            _: i64,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
    }

    struct FakeWeatherGateway {
        rows: Vec<WeatherData>,
    }

    impl WeatherDataGateway for FakeWeatherGateway {
        fn weather_data_for_period(&self, _: i64, _: Date, _: Date) -> Vec<WeatherData> {
            self.rows.clone()
        }

        fn weather_data_count(&self, _: i64, start: Option<Date>, end: Option<Date>) -> i64 {
            if start.is_some() && end.is_some() {
                1
            } else {
                0
            }
        }

        fn historical_data_count(&self, _: i64, _: Date, _: Date) -> i64 {
            10_000
        }

        fn earliest_date(&self, _: i64) -> Option<Date> {
            Some(Date::from_calendar_date(2020, Month::January, 1).expect("valid"))
        }

        fn latest_date(&self, _: i64) -> Option<Date> {
            Some(Date::from_calendar_date(2024, Month::January, 1).expect("valid"))
        }

        fn upsert_weather_data(
            &self,
            _: &[WeatherData],
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }

        fn find_by_coordinates(
            &self,
            _: f64,
            _: f64,
        ) -> Option<crate::weather_data::gateways::WeatherLocationRecord> {
            None
        }

        fn find_or_create_weather_location(
            &self,
            _: f64,
            _: f64,
            _: Option<f64>,
            _: Option<&str>,
        ) -> Result<crate::weather_data::gateways::WeatherLocationRecord, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(crate::weather_data::gateways::WeatherLocationRecord { id: 1 })
        }

        fn update_predicted_weather_data(
            &self,
            _: i64,
            _: &serde_json::Value,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
    }

    struct FakeEnqueue;
    impl PredictWeatherStandaloneEnqueuePort for FakeEnqueue {
        fn enqueue_predict_weather_standalone(
            &self,
            _: i64,
            _: Option<i32>,
            _: &str,
            _: Option<Date>,
            _: Option<i64>,
            _: Option<&str>,
        ) -> PredictWeatherStandaloneEnqueueResult {
            PredictWeatherStandaloneEnqueueResult::success()
        }
    }

    struct FakeParse;
    impl FarmWeatherPredictionPayloadParsePort for FakeParse {
        fn predicted_at_from_payload(&self, _: Option<&str>) -> Option<OffsetDateTime> {
            Some(OffsetDateTime::new_utc(
                Date::from_calendar_date(2026, Month::January, 1).expect("valid"),
                Time::MIDNIGHT,
            ))
        }

        fn prediction_start_date_from_payload(&self, _: Option<&str>) -> Option<Date> {
            Some(Date::from_calendar_date(2026, Month::January, 1).expect("valid"))
        }
    }

    struct FixedClock {
        now: OffsetDateTime,
        today: Date,
    }

    impl ClockPort for FixedClock {
        fn today(&self) -> Date {
            self.today
        }

        fn now(&self) -> OffsetDateTime {
            self.now
        }
    }

    struct NoopLogger;
    impl LoggerPort for NoopLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    #[test]
    fn index_builds_temperature_mean_from_max_min_when_dto_mean_is_nil() {
        let calls = Arc::new(Mutex::new(Vec::new()));
        let last_index = Arc::new(Mutex::new(None));
        let mut output = RecordingOutputPort {
            calls: calls.clone(),
            last_index: last_index.clone(),
        };
        let farm_gateway = FakeFarmGateway {
            ctx: Some(FarmWeatherDataAccessContext {
                farm_id: 1,
                display_name: "テスト".into(),
                latitude: 35.0,
                longitude: 139.0,
                weather_location_id: Some(9),
                predicted_weather_data: None,
            }),
        };
        let weather_gateway = FakeWeatherGateway {
            rows: vec![WeatherData::new(
                Date::from_calendar_date(2024, Month::June, 1).expect("valid"),
                Some(30.0),
                Some(20.0),
                None,
                Some(1.0),
                None,
                None,
                None,
            )],
        };
        let clock = FixedClock {
            now: OffsetDateTime::new_utc(
                Date::from_calendar_date(2026, Month::January, 1).expect("valid"),
                Time::MIDNIGHT,
            ),
            today: Date::from_calendar_date(2026, Month::January, 1).expect("valid"),
        };
        let mut interactor = FarmWeatherDataAccessInteractor::new(
            &mut output,
            &farm_gateway,
            &weather_gateway,
            &FakeEnqueue,
            &FakeParse,
            &NoopLogger,
            &clock,
        );

        interactor.call(FarmWeatherDataAccessInput {
            farm_id: 1,
            user_id: 1,
            is_admin: false,
            predict: false,
            start_date: Some(Date::from_calendar_date(2024, Month::January, 1).expect("valid")),
            end_date: Some(Date::from_calendar_date(2024, Month::December, 31).expect("valid")),
        });

        assert_eq!(calls.lock().expect("lock")[0], "index_success");
        let row = last_index.lock().expect("lock").clone().expect("row");
        assert!((row.temperature_mean - 25.0).abs() < f64::EPSILON);
    }

    #[test]
    fn returns_farm_not_found_when_gateway_returns_nil() {
        let calls = Arc::new(Mutex::new(Vec::new()));
        let mut output = RecordingOutputPort {
            calls: calls.clone(),
            last_index: Arc::new(Mutex::new(None)),
        };
        let farm_gateway = FakeFarmGateway { ctx: None };
        let weather_gateway = FakeWeatherGateway { rows: vec![] };
        let clock = FixedClock {
            now: OffsetDateTime::new_utc(
                Date::from_calendar_date(2026, Month::January, 1).expect("valid"),
                Time::MIDNIGHT,
            ),
            today: Date::from_calendar_date(2026, Month::January, 1).expect("valid"),
        };
        let mut interactor = FarmWeatherDataAccessInteractor::new(
            &mut output,
            &farm_gateway,
            &weather_gateway,
            &FakeEnqueue,
            &FakeParse,
            &NoopLogger,
            &clock,
        );

        interactor.call(FarmWeatherDataAccessInput {
            farm_id: 99,
            user_id: 1,
            is_admin: false,
            predict: false,
            start_date: None,
            end_date: None,
        });

        assert_eq!(calls.lock().expect("lock")[0], "farm_not_found");
    }
}
