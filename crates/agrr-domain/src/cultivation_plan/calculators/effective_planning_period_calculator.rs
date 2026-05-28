//! Ruby: `Domain::CultivationPlan::Calculators::EffectivePlanningPeriodCalculator`

use serde_json::Value;
use time::{Date, Duration, Month};

use crate::cultivation_plan::helpers::parse_iso_date;
use crate::cultivation_plan::errors::{
    EffectivePlanningPeriodDateField, EffectivePlanningPeriodInvalidDateError,
};

#[derive(Debug, Clone, Copy)]
pub struct CultivationPeriodDate {
    pub start_date: Option<Date>,
    pub completion_date: Option<Date>,
}

pub fn calculate(
    current_allocation: &Value,
    moves: &[Value],
    cultivation_periods: &[CultivationPeriodDate],
    planning_start_date: Option<Date>,
    planning_end_date: Option<Date>,
    as_of: Date,
) -> Result<(Date, Date), EffectivePlanningPeriodInvalidDateError> {
    let mut all_dates: Vec<Date> = Vec::new();
    append_allocation_dates(&mut all_dates, current_allocation)?;
    append_move_dates(&mut all_dates, moves)?;

    if all_dates.is_empty() {
        for cultivation in cultivation_periods {
            if let Some(d) = cultivation.start_date {
                all_dates.push(d);
            }
            if let Some(d) = cultivation.completion_date {
                all_dates.push(d);
            }
        }
    }

    if !all_dates.is_empty() {
        let min_date = *all_dates.iter().min().expect("non-empty");
        let max_date = *all_dates.iter().max().expect("non-empty");
        let start_anchor = min_date - Duration::days(365);
        let effective_start = date_ymd(start_anchor.year(), 1, 1);
        let end_anchor = max_date + Duration::days(365);
        let effective_end = date_ymd(end_anchor.year(), 12, 31);
        return Ok((effective_start, effective_end));
    }

    let mut effective_start = planning_start_date.unwrap_or(as_of);
    let mut effective_end = planning_end_date.unwrap_or_else(|| two_years_later_end_of_year(effective_start));
    if effective_start > effective_end {
        effective_end = two_years_later_end_of_year(effective_start);
    }
    Ok((effective_start, effective_end))
}

fn append_allocation_dates(
    all_dates: &mut Vec<Date>,
    current_allocation: &Value,
) -> Result<(), EffectivePlanningPeriodInvalidDateError> {
    let Some(field_schedules) = current_allocation
        .pointer("/optimization_result/field_schedules")
        .and_then(|v| v.as_array())
    else {
        return Ok(());
    };

    for field_schedule in field_schedules {
        let Some(allocations) = field_schedule.get("allocations").and_then(|v| v.as_array()) else {
            continue;
        };
        for allocation in allocations {
            let allocation_id = allocation.get("allocation_id").and_then(|v| v.as_i64());
            append_date(
                all_dates,
                allocation.get("start_date"),
                EffectivePlanningPeriodDateField::StartDate,
                allocation_id,
                None,
            )?;
            append_date(
                all_dates,
                allocation.get("completion_date"),
                EffectivePlanningPeriodDateField::CompletionDate,
                allocation_id,
                None,
            )?;
        }
    }
    Ok(())
}

fn append_move_dates(
    all_dates: &mut Vec<Date>,
    moves: &[Value],
) -> Result<(), EffectivePlanningPeriodInvalidDateError> {
    for mv in moves {
        append_date(
            all_dates,
            mv.get("to_start_date"),
            EffectivePlanningPeriodDateField::ToStartDate,
            None,
            Some(mv.clone()),
        )?;
    }
    Ok(())
}

fn two_years_later_end_of_year(date: Date) -> Date {
    let advanced = add_months(date, 24);
    date_ymd(advanced.year(), 12, 31)
}

fn add_months(date: Date, months: i32) -> Date {
    let y = date.year();
    let m = i32::from(date.month() as u8);
    let d = date.day();
    let total = y * 12 + (m - 1) + months;
    let new_y = total.div_euclid(12);
    let new_m = (total.rem_euclid(12) + 1) as u8;
    let max_day = days_in_month(new_y, new_m);
    date_ymd(new_y, new_m, d.min(max_day))
}

fn days_in_month(year: i32, month: u8) -> u8 {
    let next = if month == 12 {
        date_ymd(year + 1, 1, 1)
    } else {
        date_ymd(year, month + 1, 1)
    };
    let current = date_ymd(year, month, 1);
    (next - current).whole_days() as u8
}

fn append_date(
    all_dates: &mut Vec<Date>,
    raw_value: Option<&Value>,
    field: EffectivePlanningPeriodDateField,
    allocation_id: Option<i64>,
    move_payload: Option<Value>,
) -> Result<(), EffectivePlanningPeriodInvalidDateError> {
    let Some(raw) = raw_value else {
        return Ok(());
    };
    if raw.is_null() {
        return Ok(());
    }

    let raw_display = raw
        .as_str()
        .map(str::to_string)
        .unwrap_or_else(|| raw.to_string());
    let parsed = parse_date_value(raw).map_err(|_| {
        EffectivePlanningPeriodInvalidDateError::new(
            raw_display,
            field,
            allocation_id,
            move_payload.map(|v| v.to_string()),
        )
    })?;
    all_dates.push(parsed);
    Ok(())
}

fn parse_date_value(value: &Value) -> Result<Date, ()> {
    value
        .as_str()
        .and_then(parse_iso_date)
        .ok_or(())
}

fn date_ymd(year: i32, month: u8, day: u8) -> Date {
    Date::from_calendar_date(year, Month::try_from(month).expect("month"), day).expect("valid date")
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    // Ruby: test "calculate uses allocations and moves to extend range"
    #[test]
    fn calculate_uses_allocations_and_moves_to_extend_range() {
        let current_allocation = json!({
            "optimization_result": {
                "field_schedules": [{
                    "allocations": [{
                        "start_date": "2024-04-01",
                        "completion_date": "2024-06-01",
                        "allocation_id": 11
                    }]
                }]
            }
        });
        let moves = vec![json!({ "to_start_date": "2025-02-10" })];
        let (start_date, end_date) = calculate(
            &current_allocation,
            &moves,
            &[],
            Some(date_ymd(2023, 1, 1)),
            Some(date_ymd(2023, 12, 31)),
            date_ymd(2025, 5, 6),
        )
        .unwrap();
        assert_eq!(start_date, date_ymd(2023, 1, 1));
        assert_eq!(end_date, date_ymd(2026, 12, 31));
    }

    // Ruby: test "calculate uses planning dates or as_of when no periods exist"
    #[test]
    fn calculate_uses_planning_dates_or_as_of_when_no_periods() {
        let (start_date, end_date) = calculate(
            &json!({}),
            &[],
            &[],
            Some(date_ymd(2024, 1, 15)),
            Some(date_ymd(2024, 12, 31)),
            date_ymd(2025, 5, 6),
        )
        .unwrap();
        assert_eq!(start_date, date_ymd(2024, 1, 15));
        assert_eq!(end_date, date_ymd(2024, 12, 31));

        let (start_date, end_date) = calculate(
            &json!({}),
            &[],
            &[],
            None,
            None,
            date_ymd(2025, 5, 6),
        )
        .unwrap();
        assert_eq!(start_date, date_ymd(2025, 5, 6));
        assert_eq!(end_date, date_ymd(2027, 12, 31));
    }

    // Ruby: test "calculate raises error for invalid date"
    #[test]
    fn calculate_raises_error_for_invalid_date() {
        let err = calculate(
            &json!({
                "optimization_result": {
                    "field_schedules": [{
                        "allocations": [{
                            "start_date": "invalid-date",
                            "completion_date": null,
                            "allocation_id": 55
                        }]
                    }]
                }
            }),
            &[],
            &[],
            None,
            None,
            date_ymd(2025, 5, 6),
        )
        .unwrap_err();
        assert_eq!(err.raw_value, "invalid-date");
        assert_eq!(err.field, EffectivePlanningPeriodDateField::StartDate);
        assert_eq!(err.allocation_id, Some(55));
    }
}
