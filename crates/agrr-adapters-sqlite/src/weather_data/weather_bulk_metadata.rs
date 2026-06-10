//! SQLite-backed aggregate metadata for GCS bulk weather year files.

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};
use serde_json::Value;
use time::Date;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub(crate) struct WeatherYearStats {
    pub count: i64,
    pub historical_count: i64,
    pub first_date: String,
    pub last_date: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
pub(crate) struct WeatherBulkMetadata {
    pub earliest_date: Option<String>,
    pub latest_date: Option<String>,
    pub years: BTreeMap<String, WeatherYearStats>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) enum RangeCountPlan {
    Exact(i64),
    PartialYears {
        full_year_total: i64,
        years: Vec<i32>,
    },
    MissingMetadata,
}

pub(crate) fn is_historical_day(attrs: &Value) -> bool {
    attrs.get("temperature_max").map(value_present).unwrap_or(false)
        && attrs.get("temperature_min").map(value_present).unwrap_or(false)
}

fn value_present(value: &Value) -> bool {
    !value.is_null()
}

pub(crate) fn year_stats_from_year_file(
    year_entries: &BTreeMap<String, Value>,
) -> Option<WeatherYearStats> {
    if year_entries.is_empty() {
        return None;
    }
    let mut dates: Vec<Date> = year_entries
        .keys()
        .filter_map(|s| parse_date(s))
        .collect();
    if dates.is_empty() {
        return None;
    }
    dates.sort_unstable();
    let historical_count = year_entries
        .values()
        .filter(|attrs| is_historical_day(attrs))
        .count() as i64;
    Some(WeatherYearStats {
        count: dates.len() as i64,
        historical_count,
        first_date: dates.first().expect("non-empty").to_string(),
        last_date: dates.last().expect("non-empty").to_string(),
    })
}

pub(crate) fn recompute_bounds(metadata: &mut WeatherBulkMetadata) {
    let mut earliest: Option<Date> = None;
    let mut latest: Option<Date> = None;
    for stats in metadata.years.values() {
        if let Some(first) = parse_date(&stats.first_date) {
            earliest = Some(match earliest {
                None => first,
                Some(cur) => cur.min(first),
            });
        }
        if let Some(last) = parse_date(&stats.last_date) {
            latest = Some(match latest {
                None => last,
                Some(cur) => cur.max(last),
            });
        }
    }
    metadata.earliest_date = earliest.map(|d| d.to_string());
    metadata.latest_date = latest.map(|d| d.to_string());
}

pub(crate) fn parse_date(s: &str) -> Option<Date> {
    Date::parse(s.trim(), &time::format_description::well_known::Iso8601::DATE).ok()
}

pub(crate) fn plan_count_in_range(
    metadata: &WeatherBulkMetadata,
    start_date: Option<Date>,
    end_date: Option<Date>,
) -> RangeCountPlan {
    let (Some(start), Some(end)) = (start_date, end_date) else {
        return count_all_years(metadata);
    };
    if start > end {
        return RangeCountPlan::Exact(0);
    }

    let mut total = 0i64;
    let mut partial_years = Vec::new();
    for year in start.year()..=end.year() {
        let Some(stats) = metadata.years.get(&year.to_string()) else {
            return RangeCountPlan::MissingMetadata;
        };
        let Some(year_first) = parse_date(&stats.first_date) else {
            return RangeCountPlan::MissingMetadata;
        };
        let Some(year_last) = parse_date(&stats.last_date) else {
            return RangeCountPlan::MissingMetadata;
        };
        let overlap_start = start.max(year_first);
        let overlap_end = end.min(year_last);
        if overlap_start > overlap_end {
            continue;
        }
        if overlap_start == year_first && overlap_end == year_last {
            total += stats.count;
        } else {
            partial_years.push(year);
        }
    }

    if partial_years.is_empty() {
        RangeCountPlan::Exact(total)
    } else {
        RangeCountPlan::PartialYears {
            full_year_total: total,
            years: partial_years,
        }
    }
}

pub(crate) fn plan_historical_count_in_range(
    metadata: &WeatherBulkMetadata,
    start_date: Date,
    end_date: Date,
) -> RangeCountPlan {
    if start_date > end_date {
        return RangeCountPlan::Exact(0);
    }

    let mut total = 0i64;
    let mut partial_years = Vec::new();
    for year in start_date.year()..=end_date.year() {
        let Some(stats) = metadata.years.get(&year.to_string()) else {
            return RangeCountPlan::MissingMetadata;
        };
        let Some(year_first) = parse_date(&stats.first_date) else {
            return RangeCountPlan::MissingMetadata;
        };
        let Some(year_last) = parse_date(&stats.last_date) else {
            return RangeCountPlan::MissingMetadata;
        };
        let overlap_start = start_date.max(year_first);
        let overlap_end = end_date.min(year_last);
        if overlap_start > overlap_end {
            continue;
        }
        if overlap_start == year_first && overlap_end == year_last {
            total += stats.historical_count;
        } else {
            partial_years.push(year);
        }
    }

    if partial_years.is_empty() {
        RangeCountPlan::Exact(total)
    } else {
        RangeCountPlan::PartialYears {
            full_year_total: total,
            years: partial_years,
        }
    }
}

fn count_all_years(metadata: &WeatherBulkMetadata) -> RangeCountPlan {
    if metadata.years.is_empty() {
        RangeCountPlan::MissingMetadata
    } else {
        RangeCountPlan::Exact(
            metadata
                .years
                .values()
                .map(|stats| stats.count)
                .sum(),
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use time::Month;

    fn d(y: i32, m: u8, day: u8) -> Date {
        Date::from_calendar_date(y, Month::try_from(m).unwrap(), day).unwrap()
    }

    #[test]
    fn year_stats_from_year_file_counts_historical_days() {
        let mut entries = BTreeMap::new();
        entries.insert(
            "2024-01-01".into(),
            json!({"temperature_max": 10.0, "temperature_min": 5.0}),
        );
        entries.insert(
            "2024-01-02".into(),
            json!({"temperature_max": null, "temperature_min": 5.0}),
        );
        let stats = year_stats_from_year_file(&entries).expect("stats");
        assert_eq!(stats.count, 2);
        assert_eq!(stats.historical_count, 1);
        assert_eq!(stats.first_date, "2024-01-01");
        assert_eq!(stats.last_date, "2024-01-02");
    }

    #[test]
    fn plan_count_in_range_exact_for_full_years() {
        let metadata = WeatherBulkMetadata {
            earliest_date: Some("2023-01-01".into()),
            latest_date: Some("2024-12-31".into()),
            years: BTreeMap::from([
                (
                    "2023".into(),
                    WeatherYearStats {
                        count: 365,
                        historical_count: 365,
                        first_date: "2023-01-01".into(),
                        last_date: "2023-12-31".into(),
                    },
                ),
                (
                    "2024".into(),
                    WeatherYearStats {
                        count: 366,
                        historical_count: 366,
                        first_date: "2024-01-01".into(),
                        last_date: "2024-12-31".into(),
                    },
                ),
            ]),
        };
        assert_eq!(
            plan_count_in_range(&metadata, Some(d(2023, 1, 1)), Some(d(2024, 12, 31))),
            RangeCountPlan::Exact(731)
        );
    }

    #[test]
    fn plan_count_in_range_partial_year_needs_gcs() {
        let metadata = WeatherBulkMetadata {
            earliest_date: Some("2024-01-01".into()),
            latest_date: Some("2024-12-31".into()),
            years: BTreeMap::from([(
                "2024".into(),
                WeatherYearStats {
                    count: 366,
                    historical_count: 366,
                    first_date: "2024-01-01".into(),
                    last_date: "2024-12-31".into(),
                },
            )]),
        };
        assert_eq!(
            plan_count_in_range(&metadata, Some(d(2024, 6, 1)), Some(d(2024, 12, 31))),
            RangeCountPlan::PartialYears {
                full_year_total: 0,
                years: vec![2024],
            }
        );
    }

    #[test]
    fn recompute_bounds_sets_earliest_and_latest_from_year_stats() {
        let mut metadata = WeatherBulkMetadata {
            earliest_date: None,
            latest_date: None,
            years: BTreeMap::from([
                (
                    "2023".into(),
                    WeatherYearStats {
                        count: 1,
                        historical_count: 1,
                        first_date: "2023-01-01".into(),
                        last_date: "2023-01-01".into(),
                    },
                ),
                (
                    "2024".into(),
                    WeatherYearStats {
                        count: 1,
                        historical_count: 1,
                        first_date: "2024-12-31".into(),
                        last_date: "2024-12-31".into(),
                    },
                ),
            ]),
        };
        recompute_bounds(&mut metadata);
        assert_eq!(metadata.earliest_date.as_deref(), Some("2023-01-01"));
        assert_eq!(metadata.latest_date.as_deref(), Some("2024-12-31"));
    }
}
