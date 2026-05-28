//! Ruby: `Domain::CultivationPlan::Dtos::TaskScheduleItemAmountSnapshot`

use rust_decimal::Decimal;
use time::Date;

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleItemAmountSnapshot {
    pub amount: Option<Decimal>,
    pub amount_unit: Option<String>,
    pub scheduled_date: Date,
}
