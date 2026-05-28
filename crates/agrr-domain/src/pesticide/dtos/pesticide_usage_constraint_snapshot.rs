/// Ruby: `Domain::Pesticide::Dtos::PesticideUsageConstraintSnapshot`
#[derive(Debug, Clone, PartialEq)]
pub struct PesticideUsageConstraintSnapshot {
    pub min_temperature: Option<f64>,
    pub max_temperature: Option<f64>,
    pub max_wind_speed_m_s: Option<f64>,
    pub max_application_count: Option<i64>,
    pub harvest_interval_days: Option<i64>,
    pub other_constraints: Option<String>,
}
