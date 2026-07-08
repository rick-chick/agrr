use crate::crop::dtos::MastersCropTaskScheduleBlueprint;
use rust_decimal::Decimal;

/// Returns true when a new or updated row would conflict with an existing blueprint.
pub fn conflicts_with_existing(
    existing: &[MastersCropTaskScheduleBlueprint],
    exclude_blueprint_id: Option<i64>,
    agricultural_task_id: i64,
    stage_order: Option<i32>,
    gdd_trigger: Option<f64>,
) -> bool {
    existing.iter().any(|row| {
        if exclude_blueprint_id == Some(row.id) {
            return false;
        }
        if row.agricultural_task_id != Some(agricultural_task_id) {
            return false;
        }
        match (stage_order, row.stage_order) {
            (None, None) => true,
            (Some(order), Some(existing_order)) if order == existing_order => {
                gdd_triggers_conflict(gdd_trigger, row.gdd_trigger.as_ref())
            }
            _ => false,
        }
    })
}

fn gdd_triggers_conflict(
    candidate: Option<f64>,
    existing: Option<&Decimal>,
) -> bool {
    match (candidate, existing_decimal_as_f64(existing)) {
        (None, None) => true,
        (Some(left), Some(right)) => left == right,
        _ => false,
    }
}

fn existing_decimal_as_f64(value: Option<&Decimal>) -> Option<f64> {
    value.and_then(|decimal| decimal.to_string().parse().ok())
}

#[cfg(test)]
mod masters_crop_task_schedule_blueprint_duplicate_policy_test_inline {
    use super::*;
    use crate::agricultural_task::constants::schedule_item_types::FIELD_WORK;
    use rust_decimal::Decimal;

    fn blueprint(
        id: i64,
        agricultural_task_id: i64,
        stage_order: Option<i32>,
        gdd_trigger: Option<Decimal>,
    ) -> MastersCropTaskScheduleBlueprint {
        MastersCropTaskScheduleBlueprint {
            id,
            crop_id: 1,
            agricultural_task_id: Some(agricultural_task_id),
            source_agricultural_task_id: None,
            stage_order,
            stage_name: None,
            gdd_trigger,
            gdd_tolerance: None,
            task_type: FIELD_WORK.into(),
            source: "manual".into(),
            priority: 1,
            amount: None,
            amount_unit: None,
            description: None,
            weather_dependency: None,
            time_per_sqm: None,
            name: None,
            created_at: None,
            updated_at: None,
        }
    }

    #[test]
    fn conflicts_when_pending_row_exists_for_same_task() {
        let existing = vec![blueprint(1, 3, None, None)];
        assert!(conflicts_with_existing(&existing, None, 3, None, None));
    }

    #[test]
    fn conflicts_when_same_stage_task_and_gdd() {
        let existing = vec![blueprint(1, 3, Some(2), Some(Decimal::from(100)))];
        assert!(conflicts_with_existing(
            &existing,
            None,
            3,
            Some(2),
            Some(100.0)
        ));
    }

    #[test]
    fn conflicts_when_same_stage_task_and_both_gdd_missing() {
        let existing = vec![blueprint(1, 3, Some(2), None)];
        assert!(conflicts_with_existing(&existing, None, 3, Some(2), None));
    }

    #[test]
    fn allows_same_stage_task_with_different_gdd() {
        let existing = vec![blueprint(1, 3, Some(2), Some(Decimal::from(100)))];
        assert!(!conflicts_with_existing(
            &existing,
            None,
            3,
            Some(2),
            Some(250.0)
        ));
    }

    #[test]
    fn allows_same_task_in_different_stage() {
        let existing = vec![blueprint(1, 3, Some(1), Some(Decimal::from(100)))];
        assert!(!conflicts_with_existing(
            &existing,
            None,
            3,
            Some(2),
            Some(100.0)
        ));
    }

    #[test]
    fn excludes_self_on_update() {
        let existing = vec![blueprint(1, 3, Some(2), Some(Decimal::from(100)))];
        assert!(!conflicts_with_existing(
            &existing,
            Some(1),
            3,
            Some(2),
            Some(100.0)
        ));
    }
}
