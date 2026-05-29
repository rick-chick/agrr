// Tests for `mappers/field_cultivation_sync_plan_crop_resolver.rs` (Ruby parity under test/domain/field_cultivation/).

    use crate::field_cultivation::dtos::{
        FieldCultivationSyncExistingFieldCultivationEntry, FieldCultivationSyncPlanCropEntry,
    };
    use std::collections::HashMap;
    use time::macros::date;

    fn allocation(crop_id: &str, allocation_id: Option<i64>) -> FieldCultivationSyncAllocationInput {
        FieldCultivationSyncAllocationInput {
            allocation_id,
            external_allocation_id: None,
            crop_id: crop_id.into(),
            start_date: date!(2026 - 01 - 01),
            completion_date: date!(2026 - 01 - 02),
            area_used: None,
            area: None,
            total_cost: None,
            cost: None,
            expected_revenue: None,
            revenue: None,
            profit: None,
            accumulated_gdd: None,
        }
    }

    #[test]
    fn resolves_existing_field_cultivation_via_allocation_id() {
        let mut existing = HashMap::new();
        existing.insert(
            9,
            FieldCultivationSyncExistingFieldCultivationEntry {
                field_cultivation_id: 9,
                cultivation_plan_crop_id: 30,
                crop_id: "3".into(),
            },
        );
        let snapshot = FieldCultivationSyncPlanSnapshot {
            plan_id: 1,
            plan_fields_by_id: HashMap::new(),
            plan_crop_rows: vec![],
            existing_field_cultivations_by_id: existing,
        };
        let id = resolve_plan_crop_id(&snapshot, &allocation("3", Some(9))).unwrap();
        assert_eq!(id, Some(30));
    }

    #[test]
    fn resolves_unique_crop_id_match() {
        let snapshot = FieldCultivationSyncPlanSnapshot {
            plan_id: 1,
            plan_fields_by_id: HashMap::new(),
            plan_crop_rows: vec![FieldCultivationSyncPlanCropEntry {
                plan_crop_id: 30,
                crop_id: "3".into(),
            }],
            existing_field_cultivations_by_id: HashMap::new(),
        };
        let id = resolve_plan_crop_id(&snapshot, &allocation("3", None)).unwrap();
        assert_eq!(id, Some(30));
    }
