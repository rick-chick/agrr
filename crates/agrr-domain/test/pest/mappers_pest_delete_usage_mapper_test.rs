// Tests for `mappers/pest_delete_usage_mapper.rs` (Ruby parity under test/domain/pest/).


    #[test]
    fn from_snapshot_maps_pesticides_count() {
        let snapshot = PestDeleteUsageSnapshot {
            pesticides_count: 5,
        };

        let dto = from_snapshot(&snapshot);

        assert_eq!(dto.pesticides_count, 5);
    }
