// Tests for `dtos/field_optimization_event_snapshot.rs` (Ruby parity under test/domain/cultivation_plan/).


    // Ruby: test "to_h preserves cable shape"
    #[test]
    fn to_h_preserves_cable_shape() {
        let dto = FieldOptimizationEventSnapshot::new(7, 7, "North", 120.5);
        let h = dto.to_h();
        assert_eq!(h.get("id").and_then(|v| v.as_i64()), Some(7));
        assert_eq!(h.get("field_id").and_then(|v| v.as_i64()), Some(7));
        assert_eq!(h.get("name").and_then(|v| v.as_str()), Some("North"));
        assert!((h.get("area").and_then(|v| v.as_f64()).unwrap() - 120.5).abs() < 0.001);
    }
