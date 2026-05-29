// Tests for `mappers/field_cultivation_sync_unreferenced_plan_crop_ids.rs` (Ruby parity under test/domain/field_cultivation/).

    use crate::field_cultivation::dtos::FieldCultivationSyncPlanCropEntry;
    use std::collections::HashMap;

    #[test]
    fn returns_unreferenced_plan_crop_ids() {
        let snapshot = FieldCultivationSyncPlanSnapshot {
            plan_id: 1,
            plan_fields_by_id: HashMap::new(),
            plan_crop_rows: vec![
                FieldCultivationSyncPlanCropEntry {
                    plan_crop_id: 30,
                    crop_id: "3".into(),
                },
                FieldCultivationSyncPlanCropEntry {
                    plan_crop_id: 90,
                    crop_id: "9".into(),
                },
            ],
            existing_field_cultivations_by_id: HashMap::new(),
        };
        assert_eq!(ids_to_delete(&snapshot, &["3".into()]), vec![90]);
    }
