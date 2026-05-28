//! Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSavePesticideApplicationDetailRow`

/// Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSavePesticideApplicationDetailRow`
#[derive(Debug, Clone)]
pub struct PublicPlanSavePesticideApplicationDetailRow {
    pub dilution_ratio: Option<String>,
    pub amount_per_m2: Option<f64>,
    pub amount_unit: Option<String>,
    pub application_method: Option<String>,
}

impl PublicPlanSavePesticideApplicationDetailRow {
    pub fn new(
        dilution_ratio: Option<String>,
        amount_per_m2: Option<f64>,
        amount_unit: Option<String>,
        application_method: Option<String>,
    ) -> Self {
        Self {
            dilution_ratio,
            amount_per_m2,
            amount_unit,
            application_method,
        }
    }
}
