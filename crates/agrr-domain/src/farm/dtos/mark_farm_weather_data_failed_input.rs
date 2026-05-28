/// Ruby: `Domain::Farm::Dtos::MarkFarmWeatherDataFailedInput`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MarkFarmWeatherDataFailedInput {
    pub farm_id: i64,
    pub error_message: String,
}
