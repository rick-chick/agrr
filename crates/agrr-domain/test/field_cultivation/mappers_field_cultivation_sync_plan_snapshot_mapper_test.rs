// Tests for `mappers/field_cultivation_sync_plan_snapshot_mapper.rs` (Ruby parity under test/domain/field_cultivation/).

    use crate::field_cultivation::dtos::FieldCultivationSyncPlanCropEntry;

    #[test]
    fn from_snapshots_builds_plan_fields_map() {
        let snapshot = from_snapshots(
            1,
            vec![2, 20],
            vec![FieldCultivationSyncPlanCropEntry {
                plan_crop_id: 30,
                crop_id: "3".into(),
            }],
            vec![FieldCultivationSyncExistingFieldCultivationEntry {
                field_cultivation_id: 9,
                cultivation_plan_crop_id: 30,
                crop_id: "3".into(),
            }],
        );

        assert_eq!(snapshot.plan_id, 1);
        assert_eq!(snapshot.plan_fields_by_id.get(&2), Some(&2));
        assert!(snapshot.existing_field_cultivation_ids().contains(&9));
    }
