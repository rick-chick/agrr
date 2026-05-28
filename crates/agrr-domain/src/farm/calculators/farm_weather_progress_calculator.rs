use crate::farm::policies::FarmBroadcastThrottlePolicy;
use crate::shared::attr::{AttrMap, AttrValue};
use crate::shared::dtos::WeatherFetchDateBlock;
use time::{Date, Month};

/// Ruby: `Domain::Farm::Calculators::FarmWeatherProgressCalculator`
pub struct FarmWeatherProgressCalculator;

#[derive(Debug, Clone, PartialEq)]
pub struct WeatherFetchBlock {
    pub start_year: i32,
    pub end_year: i32,
}

impl FarmWeatherProgressCalculator {
    pub const START_YEAR: i32 = 2000;
    pub const BLOCK_SIZE: i32 = 5;

    pub fn progress_percent(fetched: Option<i32>, total: Option<i32>) -> i32 {
        let total = total.unwrap_or(0);
        if total == 0 {
            return 0;
        }
        let fetched = fetched.unwrap_or(0);
        ((fetched as f64 / total as f64) * 100.0).round() as i32
    }

    pub fn normalize_longitude(longitude: f64) -> f64 {
        ((longitude + 180.0) % 360.0) - 180.0
    }

    pub fn start_fetch_attrs(as_of_year: i32) -> AttrMap {
        let end_year = as_of_year;
        let total_years = end_year - Self::START_YEAR + 1;
        let total_blocks = ((total_years - 1) / Self::BLOCK_SIZE) + 1;
        attr_map_from_weather([
            ("weather_data_status", AttrValue::Str("fetching".into())),
            ("weather_data_fetched_years", AttrValue::Int(0)),
            (
                "weather_data_total_years",
                AttrValue::Int(total_blocks as i64),
            ),
            ("weather_data_last_error", AttrValue::Null),
        ])
    }

    /// Returns attrs to merge and whether broadcast timestamp should update.
    pub fn next_after_block(
        fetched: Option<i32>,
        total: Option<i32>,
        last_broadcast_at: Option<f64>,
        current_time: f64,
        throttle_seconds: f64,
    ) -> (AttrMap, bool) {
        let total = total.unwrap_or(0);
        if total == 0 {
            return (AttrMap::new(), false);
        }
        let fetched = fetched.unwrap_or(0);
        if fetched >= total {
            return (AttrMap::new(), false);
        }

        let new_fetched = fetched + 1;
        let throttle = FarmBroadcastThrottlePolicy::should_update_broadcast_time(
            last_broadcast_at,
            current_time,
            throttle_seconds,
        );

        let mut pairs: Vec<(&str, AttrValue)> =
            vec![("weather_data_fetched_years", AttrValue::Int(new_fetched as i64))];
        if new_fetched >= total {
            pairs.push(("weather_data_status", AttrValue::Str("completed".into())));
        }
        if throttle {
            pairs.push((
                "last_broadcast_at",
                AttrValue::Int(current_time as i64),
            ));
        }

        (attr_map_from_weather(pairs), throttle)
    }

    pub fn failed_attrs(error_message: &str) -> AttrMap {
        attr_map_from_weather([
            ("weather_data_status", AttrValue::Str("failed".into())),
            (
                "weather_data_last_error",
                AttrValue::Str(error_message.to_string()),
            ),
        ])
    }

    pub fn reset_for_coordinate_change_attrs() -> AttrMap {
        attr_map_from_weather([
            ("weather_location_id", AttrValue::Null),
            ("weather_data_status", AttrValue::Str("pending".into())),
            ("weather_data_fetched_years", AttrValue::Int(0)),
            ("weather_data_total_years", AttrValue::Int(0)),
            ("weather_data_last_error", AttrValue::Null),
        ])
    }

    pub fn weather_fetch_blocks(as_of_year: i32) -> Vec<WeatherFetchBlock> {
        let end_year = as_of_year;
        let mut blocks = Vec::new();
        let mut current_year = Self::START_YEAR;
        while current_year <= end_year {
            let block_end_year = (current_year + Self::BLOCK_SIZE - 1).min(end_year);
            blocks.push(WeatherFetchBlock {
                start_year: current_year,
                end_year: block_end_year,
            });
            current_year += Self::BLOCK_SIZE;
        }
        blocks
    }

    /// Ruby: `weather_fetch_blocks(as_of:)` with `Date` blocks for enqueue port.
    pub fn weather_fetch_date_blocks(as_of: Date) -> Vec<WeatherFetchDateBlock> {
        let end_year = as_of.year();
        let mut blocks = Vec::new();
        let mut current_year = Self::START_YEAR;
        while current_year <= end_year {
            let block_end_year = (current_year + Self::BLOCK_SIZE - 1).min(end_year);
            let start_date =
                Date::from_calendar_date(current_year, Month::January, 1).unwrap_or(as_of);
            let block_end = Date::from_calendar_date(block_end_year, Month::December, 31)
                .unwrap_or(as_of);
            let end_date = if block_end < as_of { block_end } else { as_of };
            blocks.push(WeatherFetchDateBlock {
                start_date,
                end_date,
            });
            current_year += Self::BLOCK_SIZE;
        }
        blocks
    }
}

fn attr_map_from_weather<I>(pairs: I) -> AttrMap
where
    I: IntoIterator<Item = (&'static str, AttrValue)>,
{
    let mut map = AttrMap::new();
    for (k, v) in pairs {
        map.insert(k.into(), v);
    }
    map
}

#[cfg(test)]
mod tests {
    use super::FarmWeatherProgressCalculator;

    // Ruby: test "progress_percent returns 0 when total is zero"
    #[test]
    fn progress_percent_returns_zero_when_total_zero() {
        assert_eq!(
            FarmWeatherProgressCalculator::progress_percent(Some(0), Some(0)),
            0
        );
    }

    // Ruby: test "next_after_block increments fetched and completes at total"
    #[test]
    fn next_after_block_increments_fetched_and_completes_at_total() {
        let current_time = 1_735_737_600.0;
        let (attrs, _) = FarmWeatherProgressCalculator::next_after_block(
            Some(1),
            Some(2),
            None,
            current_time,
            0.5,
        );
        assert_eq!(
            attrs.get("weather_data_fetched_years"),
            Some(&crate::shared::attr::AttrValue::Int(2))
        );
        assert_eq!(
            attrs.get("weather_data_status"),
            Some(&crate::shared::attr::AttrValue::Str("completed".into()))
        );
    }
}
