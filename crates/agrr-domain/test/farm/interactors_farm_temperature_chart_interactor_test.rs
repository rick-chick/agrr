// Tests for `interactors/farm_temperature_chart_interactor.rs`.

use crate::farm::dtos::FarmTemperatureChartInput;
use crate::farm::entities::FarmEntity;
use crate::farm::gateways::FarmGateway;
use crate::farm::ports::{
    FarmTemperatureChartFailure, FarmTemperatureChartOutputPort,
};
use crate::shared::attr::AttrMap;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::ports::ClockPort;
use crate::shared::user::User;
use crate::weather_data::dtos::WeatherData;
use crate::weather_data::gateways::WeatherDataGateway;
use time::{Date, Month};

struct FixedClock(Date);

impl ClockPort for FixedClock {
    fn today(&self) -> Date {
        self.0
    }

    fn now(&self) -> time::OffsetDateTime {
        self.0
            .with_hms(0, 0, 0)
            .unwrap()
            .assume_utc()
    }
}

struct StubLookup(User);

impl UserLookupGateway for StubLookup {
    fn find(&self, _: i64) -> User {
        self.0.clone()
    }
}

struct SpyOutput {
    success: Option<crate::farm::dtos::FarmTemperatureChartOutput>,
    failure: Option<FarmTemperatureChartFailure>,
}

impl FarmTemperatureChartOutputPort for SpyOutput {
    fn on_success(&mut self, output: crate::farm::dtos::FarmTemperatureChartOutput) {
        self.success = Some(output);
    }

    fn on_failure(&mut self, failure: FarmTemperatureChartFailure) {
        self.failure = Some(failure);
    }
}

struct StubFarmGateway {
    farm: Option<FarmEntity>,
}

impl FarmGateway for StubFarmGateway {
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
        self.farm
            .clone()
            .ok_or_else(|| Box::new(crate::shared::exceptions::RecordNotFoundError) as _)
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
        unimplemented!()
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
    ) -> Result<crate::farm::dtos::FarmDetailOutput, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }

    fn find_delete_usage(
        &self,
        _: i64,
    ) -> Result<crate::farm::dtos::FarmDeleteUsage, Box<dyn std::error::Error + Send + Sync>>
    {
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

struct StubWeatherGateway {
    rows: Vec<WeatherData>,
}

impl WeatherDataGateway for StubWeatherGateway {
    fn weather_data_for_period(
        &self,
        _: i64,
        _: Date,
        _: Date,
    ) -> Result<Vec<WeatherData>, crate::weather_data::gateways::WeatherDataStorageError> {
        Ok(self.rows.clone())
    }

    fn weather_data_count(
        &self,
        _: i64,
        _: Option<Date>,
        _: Option<Date>,
    ) -> Result<i64, crate::weather_data::gateways::WeatherDataStorageError> {
        Ok(0)
    }

    fn historical_data_count(
        &self,
        _: i64,
        _: Date,
        _: Date,
    ) -> Result<i64, crate::weather_data::gateways::WeatherDataStorageError> {
        Ok(0)
    }

    fn earliest_date(
        &self,
        _: i64,
    ) -> Result<Option<Date>, crate::weather_data::gateways::WeatherDataStorageError> {
        Ok(None)
    }

    fn latest_date(
        &self,
        _: i64,
    ) -> Result<Option<Date>, crate::weather_data::gateways::WeatherDataStorageError> {
        Ok(None)
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
}

fn completed_farm(user_id: i64) -> FarmEntity {
    FarmEntity {
        id: 12,
        name: "Test Farm".into(),
        latitude: Some(35.0),
        longitude: Some(139.0),
        region: Some("jp".into()),
        user_id: Some(user_id),
        created_at: None,
        updated_at: None,
        is_reference: false,
        weather_data_status: Some("completed".into()),
        weather_data_fetched_years: Some(20),
        weather_data_total_years: Some(20),
        weather_data_last_error: None,
        weather_location_id: Some(99),
        last_broadcast_at: None,
    }
}

#[test]
fn returns_weather_not_ready_when_status_is_fetching() {
    let mut farm = completed_farm(10);
    farm.weather_data_status = Some("fetching".into());
    let gateway = StubFarmGateway { farm: Some(farm) };
    let weather = StubWeatherGateway { rows: vec![] };
    let clock = FixedClock(Date::from_calendar_date(2026, Month::July, 21).unwrap());
    let mut output = SpyOutput {
        success: None,
        failure: None,
    };
    let lookup = StubLookup(User::new(10, false));
    let mut interactor = FarmTemperatureChartInteractor::new(
        &mut output,
        &gateway,
        &weather,
        &lookup,
        &clock,
    );
    interactor
        .call(FarmTemperatureChartInput {
            farm_id: 12,
            user_id: 10,
            period: "90d".into(),
        })
        .expect("call");

    assert_eq!(
        output.failure,
        Some(FarmTemperatureChartFailure::WeatherNotReady {
            status: "fetching".into(),
            progress: 100,
        })
    );
}

#[test]
fn returns_success_with_normalized_period_and_data_quality() {
    let gateway = StubFarmGateway {
        farm: Some(completed_farm(10)),
    };
    let end = Date::from_calendar_date(2026, Month::July, 21).unwrap();
    let start = end - time::Duration::days(89);
    let weather = StubWeatherGateway {
        rows: vec![WeatherData {
            date: start,
            temperature_max: Some(21.0),
            temperature_min: Some(8.0),
            temperature_mean: Some(14.5),
            precipitation: None,
            sunshine_hours: None,
            wind_speed: None,
            weather_code: None,
        }],
    };
    let clock = FixedClock(end);
    let mut output = SpyOutput {
        success: None,
        failure: None,
    };
    let lookup = StubLookup(User::new(10, false));
    let mut interactor = FarmTemperatureChartInteractor::new(
        &mut output,
        &gateway,
        &weather,
        &lookup,
        &clock,
    );
    interactor
        .call(FarmTemperatureChartInput {
            farm_id: 12,
            user_id: 10,
            period: "invalid".into(),
        })
        .expect("call");

    let success = output.success.expect("success");
    assert_eq!(success.period, "90d");
    assert_eq!(success.data_quality.expected_days, 90);
    assert_eq!(success.data_quality.present_days, 1);
    assert_eq!(success.data_quality.missing_days, 89);
    assert!(success.observed_only);
}

#[test]
fn normalize_period_defaults_invalid_to_90d() {
    assert_eq!(normalize_period("30d"), ("30d", 30));
    assert_eq!(normalize_period("bogus"), ("90d", 90));
}
