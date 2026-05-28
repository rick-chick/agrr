//! Ruby: `Domain::CultivationPlan::Dtos::OptimizationApplyAttrs`

use std::collections::BTreeMap;

use serde_json::{json, Value};
use time::OffsetDateTime;

/// Ruby: `Domain::CultivationPlan::Dtos::OptimizationApplyAttrs`
#[derive(Debug, Clone)]
pub struct OptimizationApplyAttrs {
    pub total_profit: f64,
    pub total_revenue: f64,
    pub total_cost: f64,
    pub optimization_time: OffsetDateTime,
    pub algorithm_used: String,
    pub is_optimal: bool,
    pub optimization_summary: String,
}

impl OptimizationApplyAttrs {
    pub fn new(
        total_profit: f64,
        total_revenue: f64,
        total_cost: f64,
        optimization_time: OffsetDateTime,
        algorithm_used: impl Into<String>,
        is_optimal: bool,
        optimization_summary: impl Into<String>,
    ) -> Self {
        Self {
            total_profit,
            total_revenue,
            total_cost,
            optimization_time,
            algorithm_used: algorithm_used.into(),
            is_optimal,
            optimization_summary: optimization_summary.into(),
        }
    }

    pub fn to_active_record_attributes(&self) -> BTreeMap<String, Value> {
        BTreeMap::from([
            ("total_profit".into(), json!(self.total_profit)),
            ("total_revenue".into(), json!(self.total_revenue)),
            ("total_cost".into(), json!(self.total_cost)),
            (
                "optimization_time".into(),
                json!(self.optimization_time.unix_timestamp()),
            ),
            ("algorithm_used".into(), json!(self.algorithm_used)),
            ("is_optimal".into(), json!(self.is_optimal)),
            (
                "optimization_summary".into(),
                json!(self.optimization_summary),
            ),
        ])
    }
}
