//! Ruby: `Domain::WeatherData::Dtos::WeatherLocation`

/// Ruby: `Domain::WeatherData::Dtos::WeatherLocation`
#[derive(Debug, Clone)]
pub struct WeatherLocation {
    pub id: i64,
    pub latitude: f64,
    pub longitude: f64,
    pub elevation: Option<f64>,
    pub timezone: Option<String>,
}

impl WeatherLocation {
    pub fn new(
        id: i64,
        latitude: f64,
        longitude: f64,
        elevation: Option<f64>,
        timezone: Option<String>,
    ) -> Self {
        Self {
            id,
            latitude,
            longitude,
            elevation,
            timezone,
        }
    }
}
