//! SQLite `planning_*_date` columns → domain planning horizon (Ruby `CultivationPlan` methods).
//!
//! `calculated_planning_*` and `prediction_target_end_date` are **not** DB columns in this app;
//! they are computed on the Rails model. Adapters must derive them from stored dates + plan type.

use time::{Date, Month};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PlanningHorizon {
    pub calculated_planning_start_date: Option<Date>,
    pub calculated_planning_end_date: Option<Date>,
    pub prediction_target_end_date: Option<Date>,
}

fn parse_ymd(s: &str) -> Option<Date> {
    let s = s.trim();
    if s.len() < 10 {
        return None;
    }
    Date::parse(&s[..10], &time::format_description::parse("[year]-[month]-[day]").ok()?).ok()
}

fn beginning_of_year(d: Date) -> Option<Date> {
    Date::from_calendar_date(d.year(), Month::January, 1).ok()
}

fn end_of_year(d: Date) -> Option<Date> {
    Date::from_calendar_date(d.year(), Month::December, 31).ok()
}

fn next_year_end(today: Date) -> Option<Date> {
    Date::from_calendar_date(today.year() + 1, Month::December, 31).ok()
}

fn default_planning_start(plan_type_private: bool, today: Date) -> Date {
    if plan_type_private {
        Date::from_calendar_date(today.year(), Month::January, 1).unwrap_or(today)
    } else {
        today
    }
}

fn default_planning_end(plan_type_private: bool, today: Date) -> Date {
    if plan_type_private {
        next_year_end(today).unwrap_or(today)
    } else {
        end_of_year(today).unwrap_or(today)
    }
}

/// Ruby parity: `CultivationPlan#calculated_planning_start_date` / `#calculated_planning_end_date` /
/// `#prediction_target_end_date` (see `app/models/cultivation_plan.rb`).
pub fn derive_planning_horizon(
    plan_type: &str,
    plan_year: Option<i32>,
    planning_start_raw: Option<&str>,
    planning_end_raw: Option<&str>,
    field_cultivation_min_start: Option<&str>,
    field_cultivation_max_completion: Option<&str>,
    today: Date,
) -> PlanningHorizon {
    let plan_type_private = plan_type == "private";
    let stored_start = planning_start_raw.and_then(parse_ymd);
    let stored_end = planning_end_raw.and_then(parse_ymd);
    let fc_min = field_cultivation_min_start.and_then(parse_ymd);
    let fc_max = field_cultivation_max_completion.and_then(parse_ymd);

    let calculated_planning_start_date = if plan_year.is_some() && stored_start.is_some() {
        stored_start
    } else if let Some(min_date) = fc_min {
        beginning_of_year(min_date).or(Some(min_date))
    } else {
        Some(default_planning_start(plan_type_private, today))
    };

    let calculated_planning_end_date = if plan_year.is_some() && stored_end.is_some() {
        stored_end
    } else if let Some(max_date) = fc_max {
        end_of_year(max_date).or(Some(max_date))
    } else {
        Some(default_planning_end(plan_type_private, today))
    };

    let prediction_target_end_date = if plan_type_private {
        calculated_planning_end_date
    } else {
        next_year_end(today)
    };

    PlanningHorizon {
        calculated_planning_start_date,
        calculated_planning_end_date,
        prediction_target_end_date,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn public_plan_without_field_cultivations_uses_stored_planning_dates_and_next_year_target() {
        let today = Date::from_calendar_date(2026, Month::May, 30).unwrap();
        let h = derive_planning_horizon(
            "public",
            None,
            Some("2026-05-30"),
            Some("2026-12-31"),
            None,
            None,
            today,
        );
        assert_eq!(
            h.calculated_planning_start_date,
            Some(Date::from_calendar_date(2026, Month::May, 30).unwrap())
        );
        assert_eq!(
            h.calculated_planning_end_date,
            Some(Date::from_calendar_date(2026, Month::December, 31).unwrap())
        );
        assert_eq!(
            h.prediction_target_end_date,
            Some(Date::from_calendar_date(2027, Month::December, 31).unwrap())
        );
    }

    #[test]
    fn private_plan_without_field_cultivations_uses_year_defaults() {
        let today = Date::from_calendar_date(2026, Month::May, 30).unwrap();
        let h = derive_planning_horizon("private", None, None, None, None, None, today);
        assert_eq!(
            h.calculated_planning_start_date,
            Some(Date::from_calendar_date(2026, Month::January, 1).unwrap())
        );
        assert_eq!(
            h.calculated_planning_end_date,
            Some(Date::from_calendar_date(2027, Month::December, 31).unwrap())
        );
        assert_eq!(h.prediction_target_end_date, h.calculated_planning_end_date);
    }
}
