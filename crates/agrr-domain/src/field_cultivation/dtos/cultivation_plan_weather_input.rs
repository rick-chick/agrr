use time::Date;

use crate::weather_data::dtos::PredictedWeatherMetadata;

/// Local stand-in for `WeatherData::CultivationPlanWeather` (no weather_data crate dep).
#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanWeatherInput {
    pub id: i64,
    pub prediction_target_end_date: Option<Date>,
    pub calculated_planning_end_date: Option<Date>,
    pub plan_metadata: Option<PredictedWeatherMetadata>,
}
