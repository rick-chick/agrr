//! Integration: cultivation plan delete undo must restore task_schedule_items and work_records.

use super::restore::restore_snapshot;
use super::schedule::schedule_destroy;
use crate::pool::SqlitePool;
use crate::work_record::work_record_integration_fixture::{
    seed_work_record_crud, work_record_integration_pool,
};
use rusqlite::params;
use std::collections::BTreeMap;

fn ensure_deletion_undo_events_table(pool: &SqlitePool) {
    pool.with_write(|conn| {
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS deletion_undo_events (
              id TEXT NOT NULL PRIMARY KEY,
              resource_type TEXT NOT NULL,
              resource_id TEXT NOT NULL,
              snapshot TEXT NOT NULL,
              metadata TEXT NOT NULL,
              deleted_by_id INTEGER,
              expires_at TEXT NOT NULL,
              state TEXT NOT NULL DEFAULT 'scheduled',
              restored_at TEXT,
              finalized_at TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );",
        )
    })
    .unwrap();
}

fn count_rows(pool: &SqlitePool, table: &str, plan_id: i64) -> i64 {
    let sql = format!("SELECT COUNT(*) FROM {table} WHERE cultivation_plan_id = ?1");
    pool.with_read(|conn| conn.query_row(&sql, params![plan_id], |row| row.get(0)))
        .unwrap()
}

fn count_task_schedule_items_for_plan(pool: &SqlitePool, plan_id: i64) -> i64 {
    pool.with_read(|conn| {
        conn.query_row(
            "SELECT COUNT(*) FROM task_schedule_items tsi
             INNER JOIN task_schedules ts ON ts.id = tsi.task_schedule_id
             WHERE ts.cultivation_plan_id = ?1",
            params![plan_id],
            |row| row.get(0),
        )
    })
    .unwrap()
}

#[test]
fn cultivation_plan_undo_restores_task_schedule_items_and_work_records() {
    let pool = work_record_integration_pool();
    ensure_deletion_undo_events_table(&pool);
    let seed = seed_work_record_crud(&pool);

    pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO work_records (
               cultivation_plan_id, field_cultivation_id, task_schedule_item_id,
               agricultural_task_id, name, task_type, actual_date, created_at, updated_at
             ) VALUES (?1, ?2, ?3, ?4, '実績', 'field_work', '2026-06-02', datetime('now'), datetime('now'))",
            params![
                seed.plan_id,
                seed.field_cultivation_id,
                seed.task_schedule_item_id,
                seed.agricultural_task_id
            ],
        )
    })
    .unwrap();

    assert_eq!(count_task_schedule_items_for_plan(&pool, seed.plan_id), 1);
    assert_eq!(count_rows(&pool, "work_records", seed.plan_id), 1);

    let scheduled = schedule_destroy(
        &pool,
        "CultivationPlan",
        seed.plan_id,
        42,
        "削除しました",
        5,
        BTreeMap::new(),
    )
    .expect("schedule destroy");

    assert_eq!(count_task_schedule_items_for_plan(&pool, seed.plan_id), 0);
    assert_eq!(count_rows(&pool, "work_records", seed.plan_id), 0);

    let snapshot_json: String = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT snapshot FROM deletion_undo_events WHERE id = ?1",
                params![scheduled.undo_token],
                |row| row.get(0),
            )
        })
        .unwrap();
    let snapshot: serde_json::Value = serde_json::from_str(&snapshot_json).unwrap();

    pool.with_write(|conn| restore_snapshot(conn, &snapshot))
        .expect("restore snapshot");

    assert_eq!(count_task_schedule_items_for_plan(&pool, seed.plan_id), 1);
    assert_eq!(count_rows(&pool, "work_records", seed.plan_id), 1);

    let linked_item_id: Option<i64> = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT task_schedule_item_id FROM work_records WHERE cultivation_plan_id = ?1 LIMIT 1",
                params![seed.plan_id],
                |row| row.get(0),
            )
        })
        .unwrap();
    assert_eq!(linked_item_id, Some(seed.task_schedule_item_id));
}
