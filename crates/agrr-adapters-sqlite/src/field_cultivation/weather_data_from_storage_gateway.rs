//! Field cultivation observed weather via `WeatherDataGateway` (Rails `CompositionRoot#weather_data_gateway`).

use agrr_domain::field_cultivation::dtos::ClimateObservedWeatherDatum;
use agrr_domain::field_cultivation::gateways::FieldCultivationWeatherDataGateway;
use agrr_domain::weather_data::dtos::WeatherData;
use agrr_domain::weather_data::gateways::{WeatherDataGateway, WeatherDataStorageError};
use agrr_domain::weather_data::mappers::OpenMeteoWeatherMapper;
use serde_json::Value;
use time::Date;

pub struct FieldCultivationWeatherDataFromStorageGateway<'a> {
    weather_data: &'a dyn WeatherDataGateway,
}

impl<'a> FieldCultivationWeatherDataFromStorageGateway<'a> {
    pub fn new(weather_data: &'a dyn WeatherDataGateway) -> Self {
        Self { weather_data }
    }
}

fn to_climate_datum(dto: WeatherData) -> ClimateObservedWeatherDatum {
    ClimateObservedWeatherDatum {
        date: dto.date,
        temperature_max: dto.temperature_max,
        temperature_min: dto.temperature_min,
        temperature_mean: dto.temperature_mean,
        precipitation: dto.precipitation,
        sunshine_hours: dto.sunshine_hours,
        wind_speed: dto.wind_speed,
        weather_code: dto.weather_code,
    }
}

impl FieldCultivationWeatherDataGateway for FieldCultivationWeatherDataFromStorageGateway<'_> {
    fn weather_data_for_period(
        &self,
        weather_location_id: i64,
        start_date: Date,
        end_date: Date,
    ) -> Result<Vec<ClimateObservedWeatherDatum>, WeatherDataStorageError> {
        self.weather_data
            .weather_data_for_period(weather_location_id, start_date, end_date)
            .map(|rows| rows.into_iter().map(to_climate_datum).collect())
    }

    fn format_for_agrr(
        &self,
        weather_data_dtos: &[ClimateObservedWeatherDatum],
        weather_location: &Value,
    ) -> Value {
        let latitude = weather_location
            .get("latitude")
            .and_then(|v| v.as_f64())
            .unwrap_or(0.0);
        let longitude = weather_location
            .get("longitude")
            .and_then(|v| v.as_f64())
            .unwrap_or(0.0);
        let elevation = weather_location
            .get("elevation")
            .and_then(|v| v.as_f64());
        let timezone = weather_location
            .get("timezone")
            .and_then(|v| v.as_str())
            .unwrap_or("Asia/Tokyo");

        let weather_rows: Vec<WeatherData> = weather_data_dtos
            .iter()
            .map(|d| {
                WeatherData::new(
                    d.date,
                    d.temperature_max,
                    d.temperature_min,
                    d.temperature_mean,
                    d.precipitation,
                    d.sunshine_hours,
                    d.wind_speed,
                    d.weather_code,
                )
            })
            .collect();

        OpenMeteoWeatherMapper::format_for_agrr(
            &weather_rows,
            latitude,
            longitude,
            elevation,
            timezone,
        )
    }
}
