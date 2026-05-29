// Tests for `interactors/entry_schedule/window_service.rs` (Ruby parity under test/domain/cultivation_plan/).


    fn ordered_stages() -> Vec<CropStageSnapshot> {
        let tr = TemperatureRequirementSnapshot {
            frost_threshold: Some(0.0),
            optimal_min: Some(10.0),
            optimal_max: Some(30.0),
            base_temperature: None,
        };
        vec![
            CropStageSnapshot {
                id: 1,
                name: "播種".into(),
                order: 1,
                temperature_requirement: Some(tr.clone()),
            },
            CropStageSnapshot {
                id: 2,
                name: "定植".into(),
                order: 2,
                temperature_requirement: Some(tr),
            },
        ]
    }

    // Ruby: test "returns merged sowing windows when daily weather satisfies thresholds"
    #[test]
    fn returns_merged_sowing_windows_when_daily_weather_satisfies_thresholds() {
        let rows: Vec<Value> = (1..=5)
            .map(|d| {
                serde_json::json!({
                    "time": format!("2026-04-{d:02}"),
                    "temperature_2m_min": 5.0,
                    "temperature_2m_max": 28.0,
                    "temperature_2m_mean": 19.0
                })
            })
            .collect();
        let result = WindowService::call(
            ordered_stages(),
            serde_json::json!({ "data": rows }),
        );
        assert!(result.eligible);
        assert!(!result.sowing_windows.is_empty());
        assert_eq!(
            result.sowing_windows[0].start_date,
            Date::from_calendar_date(2026, time::Month::April, 1).unwrap()
        );
        assert_eq!(
            result.sowing_windows[0].end_date,
            Date::from_calendar_date(2026, time::Month::April, 5).unwrap()
        );
    }

    // Ruby: test "returns empty result when weather series is missing"
    #[test]
    fn returns_empty_result_when_weather_series_is_missing() {
        let result = WindowService::call(ordered_stages(), serde_json::json!({}));
        assert!(!result.eligible);
        assert_eq!(
            result.reason_parts.get("error").and_then(|v| v.as_str()),
            Some("no_weather_series")
        );
    }
