//! Parity: `test/integration/cultivation_plan/public_plan_save_test.rb`

use super::plan_save_integration_fixture::{
    count_private_plans, plan_save_integration_pool, seed_crop_stage_requirements_copy,
    seed_plan_reuse, seed_task_schedule_copy, TEST_USER_ID,
};
use super::plan_save_persistence::PublicPlanSavePersistenceSqliteAdapter;
use agrr_domain::cultivation_plan::ports::PublicPlanSavePersistencePort;
use rusqlite::params;

fn invoke_save(
    pool: &crate::pool::SqlitePool,
    workspace: &agrr_domain::cultivation_plan::dtos::PublicPlanSaveWorkspace,
) -> agrr_domain::cultivation_plan::dtos::PublicPlanSaveFromSessionOutput {
    let adapter = PublicPlanSavePersistenceSqliteAdapter::new(pool.clone());
    adapter.execute_save(workspace).unwrap()
}

// Parity: test/integration/cultivation_plan/public_plan_save_test.rb — "reuses existing private plan when same public plan is saved twice"
#[test]
fn plan_save_reuses_existing_private_plan() {
    let pool = plan_save_integration_pool();
    let seed = seed_plan_reuse(&pool);
    let private_before = count_private_plans(&pool, TEST_USER_ID);

    let first = invoke_save(&pool, &seed.workspace);
    assert!(first.success, "{:?}", first.error_message);
    let skipped = first.skipped_items.expect("skipped_items");
    assert!(skipped.plan.is_empty(), "first save should not skip plan");

    let private_after_first = count_private_plans(&pool, TEST_USER_ID);
    assert_eq!(private_before + 1, private_after_first);

    let first_plan_id = first.new_cultivation_plan_id.expect("new plan id");

    let second = invoke_save(&pool, &seed.workspace);
    assert!(second.success, "{:?}", second.error_message);
    let second_skipped = second.skipped_items.expect("skipped_items");
    assert!(
        second_skipped.plan.contains(&first_plan_id),
        "second save should skip existing plan {:?}",
        second_skipped.plan
    );
    assert_eq!(
        private_after_first,
        count_private_plans(&pool, TEST_USER_ID),
        "private plan count should not change on second save"
    );
    assert_eq!(
        Some(first_plan_id),
        second.new_cultivation_plan_id,
        "second save should return same plan id"
    );
}

// Parity: test/integration/cultivation_plan/public_plan_save_test.rb — "copies task schedules and items from reference plan"
#[test]
fn plan_save_copies_task_schedule_items() {
    let pool = plan_save_integration_pool();
    let seed = seed_task_schedule_copy(&pool);
    let ref_task_id = seed.reference_agricultural_task_id;

    let result = invoke_save(&pool, &seed.workspace);
    assert!(result.success, "{:?}", result.error_message);
    let new_plan_id = result.new_cultivation_plan_id.expect("new plan id");

    pool.with_read(|conn| {
        let user_task_id: i64 = conn.query_row(
            "SELECT id FROM agricultural_tasks WHERE user_id = ?1 AND source_agricultural_task_id = ?2",
            params![TEST_USER_ID, ref_task_id],
            |r| r.get(0),
        )?;
        assert!(user_task_id > 0, "reference task should be copied to user");

        let schedule_count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM task_schedules WHERE cultivation_plan_id = ?1",
            params![new_plan_id],
            |r| r.get(0),
        )?;
        assert_eq!(1, schedule_count);

        let (schedule_source, category): (String, String) = conn.query_row(
            "SELECT source, category FROM task_schedules WHERE cultivation_plan_id = ?1 LIMIT 1",
            params![new_plan_id],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )?;
        assert_eq!("copied_from_public_plan", schedule_source);
        assert_eq!("general", category);

        let (item_name, time_per_sqm, amount_unit, source_ag_task_id, ag_task_id): (
            String,
            f64,
            Option<String>,
            Option<i64>,
            Option<i64>,
        ) = conn.query_row(
            "SELECT tsi.name, tsi.time_per_sqm, tsi.amount_unit, tsi.source_agricultural_task_id, tsi.agricultural_task_id \
             FROM task_schedule_items tsi \
             INNER JOIN task_schedules ts ON ts.id = tsi.task_schedule_id \
             WHERE ts.cultivation_plan_id = ?1 LIMIT 1",
            params![new_plan_id],
            |r| {
                Ok((
                    r.get(0)?,
                    r.get(1)?,
                    r.get(2)?,
                    r.get(3)?,
                    r.get(4)?,
                ))
            },
        )?;
        assert_eq!("参照作業", item_name);
        assert!((0.5 - time_per_sqm).abs() < 0.0001);
        assert_eq!(Some("kg".to_string()), amount_unit);
        assert_eq!(Some(ref_task_id), source_ag_task_id);
        assert_eq!(Some(user_task_id), ag_task_id);
        Ok(())
    })
    .unwrap();
}

// Parity: test/integration/cultivation_plan/public_plan_save_test.rb — "copies nutrient requirements for each crop stage"
#[test]
fn plan_save_copies_crop_stage_temperature_and_thermal_requirements() {
    let pool = plan_save_integration_pool();
    let seed = seed_crop_stage_requirements_copy(&pool);

    let result = invoke_save(&pool, &seed.workspace);
    assert!(result.success, "{:?}", result.error_message);

    pool.with_read(|conn| {
        let user_crop_id: i64 = conn.query_row(
            "SELECT id FROM crops WHERE user_id = ?1 AND source_crop_id = ?2",
            params![TEST_USER_ID, seed.reference_crop_id],
            |r| r.get(0),
        )?;
        let user_stage_id: i64 = conn.query_row(
            "SELECT id FROM crop_stages WHERE crop_id = ?1 AND name = ?2",
            params![user_crop_id, seed.reference_stage_name],
            |r| r.get(0),
        )?;
        let base_temperature: f64 = conn.query_row(
            "SELECT base_temperature FROM temperature_requirements WHERE crop_stage_id = ?1",
            params![user_stage_id],
            |r| r.get(0),
        )?;
        let required_gdd: f64 = conn.query_row(
            "SELECT required_gdd FROM thermal_requirements WHERE crop_stage_id = ?1",
            params![user_stage_id],
            |r| r.get(0),
        )?;
        assert!((10.0 - base_temperature).abs() < 0.0001);
        assert!((450.0 - required_gdd).abs() < 0.0001);
        Ok(())
    })
    .unwrap();

    // Re-save reuses user crop; stage copy must still backfill requirements.
    let second = invoke_save(&pool, &seed.workspace);
    assert!(second.success, "{:?}", second.error_message);
    pool.with_read(|conn| {
        let user_crop_id: i64 = conn.query_row(
            "SELECT id FROM crops WHERE user_id = ?1 AND source_crop_id = ?2",
            params![TEST_USER_ID, seed.reference_crop_id],
            |r| r.get(0),
        )?;
        let required_gdd: f64 = conn.query_row(
            "SELECT th.required_gdd FROM thermal_requirements th \
             INNER JOIN crop_stages cs ON cs.id = th.crop_stage_id \
             WHERE cs.crop_id = ?1",
            params![user_crop_id],
            |r| r.get(0),
        )?;
        assert!((450.0 - required_gdd).abs() < 0.0001);
        Ok(())
    })
    .unwrap();
}
