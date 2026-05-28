/// Ruby: `Domain::Pesticide::Dtos::PesticideApplicationDetailSnapshot`
#[derive(Debug, Clone, PartialEq)]
pub struct PesticideApplicationDetailSnapshot {
    pub dilution_ratio: Option<String>,
    pub amount_per_m2: Option<f64>,
    pub amount_unit: Option<String>,
    pub application_method: Option<String>,
}
