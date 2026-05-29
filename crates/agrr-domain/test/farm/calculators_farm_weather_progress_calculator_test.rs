// Tests for `calculators/farm_weather_progress_calculator.rs` (Ruby parity under test/domain/farm/).

use crate::farm::calculators::farm_weather_progress_calculator::FarmWeatherProgressCalculator;

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
