// Tests for `mappers/open_meteo_weather_mapper.rs` (Ruby parity under test/domain/weather_data/).

    use serde_json::json;
    use time::{Date, Month};

    #[test]
    fn from_agrr_daily_json_parses_weather_data() {
        let daily = json!({
            "time": "2025-01-15",
            "temperature_2m_max": 20.0,
            "temperature_2m_min": 10.0,
            "temperature_2m_mean": 15.0,
            "precipitation_sum": 2.5,
            "sunshine_hours": 6.0,
            "wind_speed_10m": 3.0,
            "weather_code": 0
        });

        let result = OpenMeteoWeatherMapper::from_agrr_daily_json(&daily);

        assert_eq!(
            result,
            Some(WeatherData::new(
                Date::from_calendar_date(2025, Month::January, 15).expect("valid"),
                Some(20.0),
                Some(10.0),
                Some(15.0),
                Some(2.5),
                Some(6.0),
                Some(3.0),
                Some(0),
            ))
        );
    }

    #[test]
    fn from_agrr_daily_json_returns_none_without_time() {
        let daily = json!({
            "temperature_2m_max": 20.0
        });

        assert_eq!(OpenMeteoWeatherMapper::from_agrr_daily_json(&daily), None);
    }

    #[test]
    fn format_for_agrr_builds_agrr_hash() {
        let dto = WeatherData::new(
            Date::from_calendar_date(2023, Month::January, 1).expect("valid"),
            Some(10.0),
            None,
            None,
            None,
            None,
            None,
            None,
        );
        let result = OpenMeteoWeatherMapper::format_for_agrr(&[dto], 35.0, 139.0, None, "UTC");
        assert_eq!(result["latitude"], 35.0);
        assert_eq!(result["longitude"], 139.0);
        assert_eq!(result["elevation"], 0.0);
        assert_eq!(result["timezone"], "UTC");
        assert_eq!(result["data"].as_array().map(|a| a.len()), Some(1));
    }
