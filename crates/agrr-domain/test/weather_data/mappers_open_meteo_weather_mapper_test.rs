// Tests for `mappers/open_meteo_weather_mapper.rs` (Ruby parity under test/domain/weather_data/).

    use time::{Date, Month};

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
