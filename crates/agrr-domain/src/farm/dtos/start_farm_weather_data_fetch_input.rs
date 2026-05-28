use time::Date;

/// Ruby: `Domain::Farm::Dtos::StartFarmWeatherDataFetchInput`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct StartFarmWeatherDataFetchInput {
    pub farm_id: i64,
    pub as_of: Date,
}
