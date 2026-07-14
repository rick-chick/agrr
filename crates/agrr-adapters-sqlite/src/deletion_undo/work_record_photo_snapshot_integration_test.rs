//! Integration: work record delete undo must snapshot and restore photo metadata.

use super::photo_finalize::finalize_deferred_photo_objects;
use super::restore::restore_snapshot;
use super::schedule::schedule_destroy;
use crate::pool::SqlitePool;
use crate::work_record::work_record_integration_fixture::{
    seed_work_record_crud, work_record_integration_pool,
};
use crate::WorkRecordPhotoSqliteGateway;
use crate::WorkRecordSqliteGateway;
use agrr_adapters_gcs::WorkRecordPhotoGcsStore;
use agrr_domain::deletion_undo::gateways::DeletionUndoGateway;
use agrr_domain::work_record::gateways::{
    WorkRecordCreatePersistAttrs, WorkRecordGateway, WorkRecordPhotoGateway,
    WorkRecordPhotoObjectStoreGateway,
};
use rust_decimal::Decimal;
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

fn count_photos_for_record(pool: &SqlitePool, work_record_id: i64) -> i64 {
    pool.with_read(|conn| {
        conn.query_row(
            "SELECT COUNT(*) FROM work_record_photos WHERE work_record_id = ?1",
            rusqlite::params![work_record_id],
            |row| row.get(0),
        )
    })
    .unwrap()
}

#[test]
fn work_record_undo_restores_photo_metadata() {
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
                name: "写真付き作業".into(),
                task_type: Some("field_work".into()),
                actual_date: Date::from_calendar_date(2026, time::Month::June, 12).unwrap(),
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
            "work_record_photos/10/99/test.jpg",
            "image/jpeg",
            now,
        )
        .expect("insert pending");
    photo_gateway
        .mark_ready(seed.plan_id, created.id, pending.id, 128, 0, now)
        .expect("mark ready");

    assert_eq!(count_photos_for_record(&pool, created.id), 1);

    let scheduled = schedule_destroy(
        &pool,
        "WorkRecord",
        created.id,
        42,
        "削除しました",
        5,
        std::collections::BTreeMap::new(),
    )
    .expect("schedule destroy");

    assert_eq!(count_photos_for_record(&pool, created.id), 0);

    let snapshot_json: String = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT snapshot FROM deletion_undo_events WHERE id = ?1",
                rusqlite::params![scheduled.undo_token],
                |row| row.get(0),
            )
        })
        .unwrap();
    let snapshot: serde_json::Value = serde_json::from_str(&snapshot_json).unwrap();

    let photos = snapshot
        .pointer("/associations/work_record_photos")
        .and_then(|v| v.as_array())
        .unwrap_or_else(|| panic!("snapshot must include work_record_photos association"));
    assert_eq!(photos.len(), 1);
    assert_eq!(
        photos[0].get("model").and_then(|v| v.as_str()),
        Some("WorkRecordPhoto")
    );

    pool.with_write(|conn| restore_snapshot(conn, &snapshot))
        .expect("restore snapshot");

    assert_eq!(count_photos_for_record(&pool, created.id), 1);
}

#[test]
fn work_record_undo_expire_finalizes_ready_photo_objects() {
    let pool = work_record_integration_pool();
    ensure_deletion_undo_events_table(&pool);
    let seed = seed_work_record_crud(&pool);
    let record_gateway = WorkRecordSqliteGateway::new(pool.clone());
    let photo_gateway = WorkRecordPhotoSqliteGateway::new(pool.clone());
    let now = OffsetDateTime::now_utc();
    let storage_key = "work_record_photos/10/42/finalize.jpg";
    let store = WorkRecordPhotoGcsStore::with_local_root(std::env::temp_dir().join(format!(
        "agrr_wr_photo_finalize_{}",
        std::process::id()
    )));
    store
        .write_object(storage_key, "image/jpeg", b"jpeg-bytes")
        .expect("seed object");

    let created = record_gateway
        .create(
            seed.plan_id,
            WorkRecordCreatePersistAttrs {
                field_cultivation_id: Some(seed.field_cultivation_id),
                task_schedule_item_id: Some(seed.task_schedule_item_id),
                agricultural_task_id: Some(seed.agricultural_task_id),
                name: "写真削除待ち".into(),
                task_type: Some("field_work".into()),
                actual_date: Date::from_calendar_date(2026, time::Month::June, 12).unwrap(),
                amount: None,
                amount_unit: None,
                time_spent_minutes: None,
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
            storage_key,
            "image/jpeg",
            now,
        )
        .expect("insert pending");
    photo_gateway
        .mark_ready(seed.plan_id, created.id, pending.id, 10, 0, now)
        .expect("mark ready");

    let scheduled = schedule_destroy(
        &pool,
        "WorkRecord",
        created.id,
        42,
        "削除しました",
        5,
        std::collections::BTreeMap::new(),
    )
    .expect("schedule destroy");

    assert!(
        store.read_object(storage_key).expect("read").is_some(),
        "object must remain during undo window"
    );

    pool.with_write(|conn| {
        conn.execute(
            "UPDATE deletion_undo_events SET expires_at = datetime('now', '-1 second') WHERE id = ?1",
            rusqlite::params![scheduled.undo_token],
        )
    })
    .unwrap();

    let gateway = super::DeletionUndoSqliteGateway::new(pool.clone());
    gateway
        .expire_if_needed(&scheduled.undo_token)
        .expect("expire");
    finalize_deferred_photo_objects(&gateway, &scheduled.undo_token, &store).expect("finalize");

    assert!(
        store.read_object(storage_key).expect("read").is_none(),
        "object must be deleted after undo expires"
    );
}
