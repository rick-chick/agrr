// Tests for `mappers/optimization_plan_snapshot_mapper.rs` (Ruby parity under test/domain/cultivation_plan/).

    use serde_json::json;
    use time::macros::date;

    // Ruby: test "to_snapshot builds OptimizationPlanSnapshot from weather DTOs"
    #[test]
    fn to_snapshot_builds_optimization_plan_snapshot_from_weather_dtos() {
        let target_end = date!(2027-12-31);
        let weather_location = WeatherLocation::new(
            1,
            35.0,
            139.0,
            Some(0.0),
            Some("Asia/Tokyo".into()),
            Some(json!({ "x": 1 })),
        );
        let farm_weather = FarmWeatherPrediction::new(2, 1, Some(json!({ "y": 2 })));

        let snapshot = to_snapshot(
            42,
            false,
            None,
            None,
            Some(target_end),
            None,
            Some(10.0),
            true,
            Some(weather_location),
            Some(farm_weather),
        );

        assert_eq!(snapshot.plan_id, 42);
        assert!(!snapshot.plan_type_private);
        assert!(snapshot.weather_location_present);
        assert_eq!(snapshot.weather_location_input.as_ref().unwrap().id, 1);
        assert_eq!(snapshot.farm_weather_input.as_ref().unwrap().id, 2);
    }
