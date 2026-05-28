//! Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSavePesticideUsageConstraintRow`

/// Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSavePesticideUsageConstraintRow`
#[derive(Debug, Clone)]
pub struct PublicPlanSavePesticideUsageConstraintRow {
    pub min_temperature: Option<f64>,
    pub max_temperature: Option<f64>,
    pub max_wind_speed_m_s: Option<f64>,
    pub max_application_count: Option<i32>,
    pub harvest_interval_days: Option<i32>,
    pub other_constraints: Option<String>,
}

impl PublicPlanSavePesticideUsageConstraintRow {
    pub fn new(
        min_temperature: Option<f64>,
        max_temperature: Option<f64>,
        max_wind_speed_m_s: Option<f64>,
        max_application_count: Option<i32>,
        harvest_interval_days: Option<i32>,
        other_constraints: Option<String>,
    ) -> Self {
        Self {
            min_temperature,
            max_temperature,
            max_wind_speed_m_s,
            max_application_count,
            harvest_interval_days,
            other_constraints,
        }
    }
}
