//! Ruby: plan copy field row.

#[derive(Debug, Clone, PartialEq)]
pub struct PlanCopyFieldRow {
    pub id: i64,
    pub name: String,
    pub area: f64,
    pub daily_fixed_cost: f64,
    pub description: Option<String>,
}
