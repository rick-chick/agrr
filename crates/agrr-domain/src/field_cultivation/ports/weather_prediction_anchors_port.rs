use time::Date;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct WeatherPredictionAnchors {
    pub training_start_date: Date,
    pub training_end_date: Date,
}

pub trait WeatherPredictionAnchorsPort: Send + Sync {
    fn anchors_for(&self, reference_calendar_day: Date) -> WeatherPredictionAnchors;
}
