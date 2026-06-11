//! Master field snapshot copied into a private plan at creation time.

#[derive(Debug, Clone, PartialEq)]
pub struct PrivatePlanMasterFieldSeed {
    pub name: String,
    pub area: f64,
    pub daily_fixed_cost: Option<f64>,
}
