// Tests for `mappers/farm_delete_usage_mapper.rs` (Ruby parity under test/domain/farm/).


    #[test]
    fn from_snapshot_maps_free_crop_plans_count() {
        let snapshot = FarmDeleteUsageSnapshot {
            free_crop_plans_count: 4,
        };

        let dto = from_snapshot(&snapshot);

        assert_eq!(dto.free_crop_plans_count, 4);
    }
