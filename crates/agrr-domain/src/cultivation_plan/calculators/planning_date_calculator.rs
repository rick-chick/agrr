//! Ruby: `Domain::CultivationPlan::Calculators::PlanningDateCalculator`

use rust_decimal::Decimal;
use time::{Date, Duration, Month};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PlanningDateRange {
    pub start_date: Date,
    pub end_date: Date,
}

pub trait PlanningDateLogger {
    fn info(&self, message: &str);
    fn debug(&self, message: &str);
}

pub fn calculate_planning_dates_for_year(plan_year: i32) -> PlanningDateRange {
    PlanningDateRange {
        start_date: date_ymd(plan_year, 1, 1),
        end_date: date_ymd(plan_year + 1, 12, 31),
    }
}

pub fn calculate_public_planning_dates(as_of: Date) -> PlanningDateRange {
    PlanningDateRange {
        start_date: as_of,
        end_date: date_ymd(as_of.year() + 1, 12, 31),
    }
}

pub fn normalize_decimal(value: Option<Decimal>) -> Option<String> {
    value.map(|d| d.normalize().to_string())
}

#[derive(Debug, Clone, Copy)]
pub struct CultivationPeriod {
    pub start_date: Date,
    pub completion_date: Date,
}

pub fn calculate_plan_year_from_cultivations(
    cultivation_periods: &[CultivationPeriod],
    logger: &dyn PlanningDateLogger,
    as_of: Date,
) -> i32 {
    if cultivation_periods.is_empty() {
        logger.info(&format!(
            "⚠️ [PlanSaveService] No field_cultivations found, using as_of year: {}",
            as_of.year()
        ));
        return as_of.year();
    }

    let midpoints: Vec<Date> = cultivation_periods
        .iter()
        .map(|c| {
            let days = (c.completion_date - c.start_date).whole_days();
            c.start_date + Duration::days(days / 2)
        })
        .collect();

    let julian_days: Vec<i32> = midpoints.iter().map(|d| d.to_julian_day()).collect();
    let avg_julian = julian_days.iter().sum::<i32>() / julian_days.len() as i32;
    let avg_date = Date::from_julian_day(avg_julian).expect("valid julian day");
    let plan_year = avg_date.year();

    logger.debug(&format!(
        "📊 [PlanSaveService] Field cultivations count: {}",
        cultivation_periods.len()
    ));
    logger.debug(&format!("📊 [PlanSaveService] Average midpoint date: {avg_date}"));
    logger.debug(&format!("📊 [PlanSaveService] Calculated plan_year: {plan_year}"));

    plan_year
}

pub fn calculate_planning_dates_from_cultivations(
    cultivation_periods: &[CultivationPeriod],
    logger: &dyn PlanningDateLogger,
    as_of: Date,
) -> PlanningDateRange {
    if cultivation_periods.is_empty() {
        logger.info(&format!(
            "⚠️ [PlanSaveService] No field_cultivations found, using default 2-year window from as_of: {as_of}"
        ));
        return PlanningDateRange {
            start_date: date_ymd(as_of.year(), 1, 1),
            end_date: date_ymd(as_of.year() + 1, 12, 31),
        };
    }

    let min_start = cultivation_periods
        .iter()
        .map(|p| p.start_date)
        .min()
        .expect("non-empty");
    let max_end = cultivation_periods
        .iter()
        .map(|p| p.completion_date)
        .max()
        .expect("non-empty");

    let planning_start = date_ymd(min_start.year(), 1, 1);
    let planning_end = date_ymd(max_end.year(), 12, 31);

    logger.debug(&format!(
        "📊 [PlanSaveService] Field cultivations count: {}",
        cultivation_periods.len()
    ));
    logger.debug(&format!(
        "📊 [PlanSaveService] Min start date: {min_start}, Max end date: {max_end}"
    ));
    logger.debug(&format!(
        "📊 [PlanSaveService] Calculated planning dates: {planning_start} to {planning_end}"
    ));

    PlanningDateRange {
        start_date: planning_start,
        end_date: planning_end,
    }
}

fn date_ymd(year: i32, month: u8, day: u8) -> Date {
    Date::from_calendar_date(year, Month::try_from(month).expect("month"), day).expect("valid date")
}

#[cfg(test)]
mod calculators_planning_date_calculator_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/calculators_planning_date_calculator_test.rs"));
}
