//! Ruby: `Domain::WeatherData::Dtos::CultivationPlanWeather`

use time::Date;

use crate::weather_data::dtos::PredictedWeatherMetadata;

/// Ruby: `Domain::WeatherData::Dtos::CultivationPlanWeather`
#[derive(Debug, Clone)]
pub struct CultivationPlanWeather {
    pub id: i64,
    pub prediction_target_end_date: Option<Date>,
    pub calculated_planning_end_date: Option<Date>,
    pub plan_metadata: Option<PredictedWeatherMetadata>,
}

impl CultivationPlanWeather {
    pub fn new(
        id: i64,
        prediction_target_end_date: Option<Date>,
        calculated_planning_end_date: Option<Date>,
        plan_metadata: Option<PredictedWeatherMetadata>,
    ) -> Self {
        Self {
            id,
            prediction_target_end_date,
            calculated_planning_end_date,
            plan_metadata,
        }
    }

    pub fn plan_metadata(&self) -> Option<&PredictedWeatherMetadata> {
        self.plan_metadata.as_ref()
    }
}
