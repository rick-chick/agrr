// Tests for `interactors/farm_temperature_chart_interactor.rs`.

use crate::farm::dtos::{
    FarmTemperatureChartDataQuality, FarmTemperatureChartInput, FarmTemperatureChartOutput,
    FarmTemperatureChartPoint,
};
use crate::farm::entities::FarmEntity;
use crate::farm::gateways::{FarmGateway, FarmTemperatureChartWeatherGateway};
use crate::farm::interactors::FarmTemperatureChartInteractor;
use crate::farm::ports::{FarmTemperatureChartOutputPort, TemperatureChartFailure};
use crate::shared::attr::AttrMap;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::ports::ClockPort;
use crate::shared::user::User;
use crate::weather_data::dtos::WeatherData;
use crate::weather_data::gateways::WeatherDataStorageError;
use time::{Date, Month, OffsetDateTime};

struct FixedClock(Date);

impl ClockPort for FixedClock {
    fn today(&self) -> Date {
        self.0
    }

    fn now(&self) -> OffsetDateTime {
        OffsetDateTime::now_utc()
    }
}

struct StubLookup(User);

impl UserLookupGateway for StubLookup {
    fn find(&self, _: i64) -> User {
        self.0.clone()
    }
}

struct SpyOutput {
    success: Option<FarmTemperatureChartOutput>,
    failure: Option<TemperatureChartFailure>,
}

impl FarmTemperatureChartOutputPort for SpyOutput {
    fn on_success(&mut self, output: FarmTemperatureChartOutput) {
        self.success = Some(output);
    }

    fn on_failure(&mut self, error: TemperatureChartFailure) {
        self.failure = Some(error);
    }
}

fn completed_farm(user_id: i64) -> FarmEntity {
    FarmEntity {
        id: 12,
        name: "Farm".into(),
        latitude: Some(35.0),
        longitude: Some(139.0),
        region: None,
        user_id: Some(user_id),
        created_at: None,
        updated_at: None,
        is_reference: false,
        weather_data_status: Some("completed".into()),
        weather_data_fetched_years: Some(5),
        weather_data_total_years: Some(5),
        weather_data_last_error: None,
        weather_location_id: Some(99),
        last_broadcast_at: None,
    }
}

fn fetching_farm(user_id: i64) -> FarmEntity {
    FarmEntity {
        weather_data_status: Some("fetching".into()),
        weather_data_fetched_years: Some(2),
        weather_data_total_years: Some(5),
        weather_location_id: Some(99),
        ..completed_farm(user_id)
    }
}

struct StubFarmGateway {
    farm: FarmEntity,
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
        Ok(self.farm.clone())
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
    ) -> Result<crate::farm::dtos::FarmDetailOutput, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_delete_usage(
        &self,
        _: i64,
    ) -> Result<crate::farm::dtos::FarmDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
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

impl FarmTemperatureChartWeatherGateway for StubWeatherGateway {
    fn weather_data_for_period(
        &self,
        _: i64,
        _: Date,
        _: Date,
    ) -> Result<Vec<WeatherData>, WeatherDataStorageError> {
        Ok(self.rows.clone())
    }
}

#[test]
fn returns_weather_not_ready_when_status_is_fetching() {
    let farm_gateway = StubFarmGateway {
        farm: fetching_farm(10),
    };
    let weather_gateway = StubWeatherGateway { rows: vec![] };
    let clock = FixedClock(Date::from_calendar_date(2026, Month::July, 21).unwrap());
    let lookup = StubLookup(User::new(10, false));
    let mut output = SpyOutput {
        success: None,
        failure: None,
    };

    let mut interactor = FarmTemperatureChartInteractor::new(
        &mut output,
        10,
        &farm_gateway,
        &weather_gateway,
        &clock,
        &lookup,
    );

    interactor
        .call(FarmTemperatureChartInput::new(12, None))
        .expect("call");

    assert!(output.success.is_none());
    assert_eq!(
        output.failure,
        Some(TemperatureChartFailure::WeatherNotReady {
            status: "fetching".into(),
            progress: 40,
        })
    );
}

#[test]
fn returns_chart_points_for_completed_farm_with_default_period() {
    let farm_gateway = StubFarmGateway {
        farm: completed_farm(10),
    };
    let end = Date::from_calendar_date(2026, Month::July, 21).unwrap();
    let start = Date::from_calendar_date(2026, Month::April, 23).unwrap();
    let weather_gateway = StubWeatherGateway {
        rows: vec![WeatherData::new(
            start,
            Some(21.0),
            Some(8.2),
            Some(14.5),
            None,
            None,
            None,
            None,
        )],
    };
    let clock = FixedClock(end);
    let lookup = StubLookup(User::new(10, false));
    let mut output = SpyOutput {
        success: None,
        failure: None,
    };

    let mut interactor = FarmTemperatureChartInteractor::new(
        &mut output,
        10,
        &farm_gateway,
        &weather_gateway,
        &clock,
        &lookup,
    );

    interactor
        .call(FarmTemperatureChartInput::new(12, None))
        .expect("call");

    let success = output.success.expect("success");
    assert_eq!(success.farm_id, 12);
    assert_eq!(success.period, "90d");
    assert_eq!(success.start_date, start);
    assert_eq!(success.end_date, end);
    assert!(success.observed_only);
    assert_eq!(
        success.data_quality,
        FarmTemperatureChartDataQuality {
            expected_days: 90,
            present_days: 1,
            missing_days: 89,
        }
    );
    assert_eq!(
        success.points,
        vec![FarmTemperatureChartPoint {
            date: start,
            temperature_min: Some(8.2),
            temperature_mean: Some(14.5),
            temperature_max: Some(21.0),
        }]
    );
}
