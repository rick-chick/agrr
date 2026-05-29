// Tests for `calculators/entry_schedule_stage_gdd_scaler.rs` (Ruby parity under test/domain/cultivation_plan/).

    use serde_json::json;

    // Ruby: test "scales down stage required_gdd when sum exceeds cap"
    #[test]
    fn scales_down_stage_required_gdd_when_sum_exceeds_cap() {
        let req = json!({
            "stage_requirements": [
                { "thermal": { "required_gdd": 800.0 } },
                { "thermal": { "required_gdd": 800.0 } }
            ]
        });
        let out = call(&req, Some(1000.0), None);
        let stages = out["stage_requirements"].as_array().unwrap();
        let total: f64 = stages
            .iter()
            .filter_map(|s| s["thermal"]["required_gdd"].as_f64())
            .sum();
        assert!((total - 1000.0).abs() < 0.01);
        assert!((stages[0]["thermal"]["required_gdd"].as_f64().unwrap() - 500.0).abs() < 0.01);
    }

    // Ruby: test "returns copy unchanged when sum is within cap"
    #[test]
    fn returns_copy_unchanged_when_sum_within_cap() {
        let req = json!({
            "stage_requirements": [
                { "thermal": { "required_gdd": 100.0 } }
            ]
        });
        let out = call(&req, Some(1000.0), None);
        assert!(
            (out["stage_requirements"][0]["thermal"]["required_gdd"]
                .as_f64()
                .unwrap()
                - 100.0)
                .abs()
                < 0.01
        );
    }
