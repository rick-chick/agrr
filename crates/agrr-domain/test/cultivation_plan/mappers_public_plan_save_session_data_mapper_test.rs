// Tests for `mappers/public_plan_save_session_data_mapper.rs` (Ruby parity under test/domain/cultivation_plan/).


    // Ruby: test "from_snapshots builds session dto from header and field rows"
    #[test]
    fn from_snapshots_builds_session_dto_from_header_and_field_rows() {
        let header = PublicPlanSaveHeaderSnapshot::new(99, Some(7));
        let field_rows = vec![PublicPlanSaveFieldDatum::new(
            Some("F1"),
            Some(5.0),
            vec![35.0, 139.0],
        )];

        let dto = from_snapshots(&header, &field_rows);

        assert_eq!(dto.plan_id, 99);
        assert_eq!(dto.farm_id, Some(7));
        assert_eq!(dto.field_data.len(), 1);
        assert_eq!(dto.field_data[0].name.as_deref(), Some("F1"));
    }
