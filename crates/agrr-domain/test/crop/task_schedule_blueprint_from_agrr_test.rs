// Tests for `task_schedule_blueprint_from_agrr.rs` (Ruby parity under test/domain/crop/).

use serde_json::json;

    use rust_decimal::Decimal;
    use std::str::FromStr;

    // Ruby: test "fertilizer_row assigns basal then topdress task types from index"
    #[test]
    fn fertilizer_row_assigns_basal_then_topdress_task_types_from_index() {
        let first = fertilizer_row(1, &json!({"task_id":"1","stage_order":0}), 0, 10, None, None, None);
        let second = fertilizer_row(1, &json!({"task_id":"2","stage_order":1}), 1, 11, None, None, None);
        assert_eq!(first.task_type, schedule_item_types::BASAL_FERTILIZATION);
        assert_eq!(second.task_type, schedule_item_types::TOPDRESS_FERTILIZATION);
        assert_eq!(first.stage_name.as_deref(), Some("基肥"));
        assert_eq!(second.stage_name.as_deref(), Some("追肥"));
    }

    // Ruby: test "general_row uses field_work task type"
    #[test]
    fn general_row_uses_field_work_task_type() {
        let row = general_row(5, &json!({"task_id":"9","stage_order":1,"gdd_trigger":0}), 9, 100, None, None, None);
        assert_eq!(row.task_type, schedule_item_types::FIELD_WORK);
        assert_eq!(row.source, "agrr_schedule");
        assert_eq!(row.crop_id, 5);
        assert_eq!(row.blueprint_id, Some(9));
        assert_eq!(row.agricultural_task_id, 100);
    }

    // Ruby: test "integer_value and decimal_value coerce API-like strings"
    #[test]
    fn integer_and_decimal_value_coerce_api_like_strings() {
        assert_eq!(integer_value(Some(&json!("42"))), Some(42));
        assert_eq!(integer_value(Some(&json!("x"))), None);
        assert_eq!(decimal_value(Some("1.5")), Some(Decimal::from_str("1.5").unwrap()));
    }
