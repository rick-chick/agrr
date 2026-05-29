// Tests for `dtos/public_plan_save_session_data.rs` (Ruby parity under test/domain/cultivation_plan/).

    use serde_json::json;

    // Ruby: test "from_session_hash builds dto from plain hash"
    #[test]
    fn from_session_hash_builds_dto_from_plain_hash() {
        let mut h = BTreeMap::new();
        h.insert("plan_id".into(), json!(99));
        h.insert("farm_id".into(), json!(5));
        h.insert("field_data".into(), json!([]));
        let dto = PublicPlanSaveSessionData::from_session_hash(Some(&h)).unwrap();
        assert_eq!(dto.plan_id, 99);
        assert_eq!(dto.farm_id, Some(5));
    }
