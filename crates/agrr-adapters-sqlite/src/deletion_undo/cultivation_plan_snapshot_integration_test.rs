//! Integration: cultivation plan delete undo must restore task_schedule_items, work_records, and photos.

use super::restore::restore_snapshot;
use super::schedule::schedule_destroy;
use crate::pool::SqlitePool;
use crate::work_record::work_record_integration_fixture::{
    seed_work_record_crud, work_record_integration_pool,
};
use crate::WorkRecordPhotoSqliteGateway;
use crate::WorkRecordSqliteGateway;
use agrr_domain::work_record::gateways::{
    WorkRecordCreatePersistAttrs, WorkRecordGateway, WorkRecordPhotoGateway,
};
use rusqlite::params;
use rust_decimal::Decimal;
use std::collections::BTreeMap;
use std::str::FromStr;
use time::{Date, OffsetDateTime};

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

fn count_photos_for_plan(pool: &SqlitePool, plan_id: i64) -> i64 {
    pool.with_read(|conn| {
        conn.query_row(
            "SELECT COUNT(*) FROM work_record_photos WHERE cultivation_plan_id = ?1",
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
    let record_gateway = WorkRecordSqliteGateway::new(pool.clone());
    let photo_gateway = WorkRecordPhotoSqliteGateway::new(pool.clone());
    let now = OffsetDateTime::now_utc();

    let created = record_gateway
        .create(
            seed.plan_id,
            WorkRecordCreatePersistAttrs {
                field_cultivation_id: Some(seed.field_cultivation_id),
                task_schedule_item_id: Some(seed.task_schedule_item_id),
                agricultural_task_id: Some(seed.agricultural_task_id),
                name: "実績".into(),
                task_type: Some("field_work".into()),
                actual_date: Date::from_calendar_date(2026, time::Month::June, 2).unwrap(),
                amount: Decimal::from_str("1.0").ok(),
                amount_unit: Some("ha".into()),
                time_spent_minutes: Some(30),
                notes: None,
                created_at: now,
                updated_at: now,
            },
        )
        .expect("create work record");

    let pending = photo_gateway
        .insert_pending(
            seed.plan_id,
            created.id,
            "work_record_photos/10/1/plan-photo.jpg",
            "image/jpeg",
            now,
        )
        .expect("insert pending");
    photo_gateway
        .mark_ready(seed.plan_id, created.id, pending.id, 64, 0, now)
        .expect("mark ready");

    assert_eq!(count_task_schedule_items_for_plan(&pool, seed.plan_id), 1);
    assert_eq!(count_rows(&pool, "work_records", seed.plan_id), 1);
    assert_eq!(count_photos_for_plan(&pool, seed.plan_id), 1);

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
    assert_eq!(count_photos_for_plan(&pool, seed.plan_id), 0);

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

    let work_records = snapshot
        .pointer("/associations/work_records")
        .and_then(|v| v.as_array())
        .unwrap_or_else(|| panic!("snapshot must include work_records association"));
    assert_eq!(work_records.len(), 1, "snapshot must capture work_records before delete");
    assert_eq!(
        work_records[0].get("model").and_then(|v| v.as_str()),
        Some("WorkRecord")
    );

    let task_schedules = snapshot
        .pointer("/associations/task_schedules")
        .and_then(|v| v.as_array())
        .unwrap_or_else(|| panic!("snapshot must include task_schedules association"));
    assert_eq!(task_schedules.len(), 1, "snapshot must capture task_schedules before delete");
    let nested_items = task_schedules[0]
        .pointer("/associations/task_schedule_items")
        .and_then(|v| v.as_array())
        .unwrap_or_else(|| panic!("task_schedule snapshot must nest task_schedule_items"));
    assert_eq!(
        nested_items.len(),
        1,
        "snapshot must capture nested task_schedule_items (P6 regression)"
    );
    assert_eq!(
        nested_items[0].get("model").and_then(|v| v.as_str()),
        Some("TaskScheduleItem")
    );

    let nested_photos = work_records[0]
        .pointer("/associations/work_record_photos")
        .and_then(|v| v.as_array())
        .unwrap_or_else(|| panic!("work_record snapshot must nest work_record_photos"));
    assert_eq!(nested_photos.len(), 1);
    assert_eq!(
        nested_photos[0].get("model").and_then(|v| v.as_str()),
        Some("WorkRecordPhoto")
    );

    pool.with_write(|conn| restore_snapshot(conn, &snapshot))
        .expect("restore snapshot");

    assert_eq!(count_task_schedule_items_for_plan(&pool, seed.plan_id), 1);
    assert_eq!(count_rows(&pool, "work_records", seed.plan_id), 1);
    assert_eq!(count_photos_for_plan(&pool, seed.plan_id), 1);

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
