//! One farm × plan row for `GET /api/v1/work/variance_portfolio`.

#[derive(Debug, Clone, PartialEq)]
pub struct VariancePortfolioRow {
    pub farm_id: i64,
    pub farm_name: String,
    pub plan_id: i64,
    pub plan_year: Option<i32>,
    pub status: String,
    pub unrecorded_count: i64,
    pub gdd_delay_count: i64,
    pub threshold_exceeded_count: i64,
    pub days_threshold_exceeded_count: i64,
    pub carryover_not_imported: bool,
    pub weather_trigger_count: i64,
}
