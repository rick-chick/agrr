//! Integration: work record photo metadata gateway roundtrip.

use super::work_record_gateway::WorkRecordSqliteGateway;
use super::work_record_integration_fixture::{seed_work_record_crud, work_record_integration_pool};
use super::work_record_photo_gateway::WorkRecordPhotoSqliteGateway;
use agrr_domain::work_record::gateways::{
    WorkRecordCreatePersistAttrs, WorkRecordGateway, WorkRecordPhotoGateway, WorkRecordPhotoStatus,
};
use agrr_domain::work_record::policies::work_record_photo_policy::MAX_PHOTOS_PER_RECORD;
use rust_decimal::Decimal;
use std::str::FromStr;
use time::{Date, OffsetDateTime};

#[test]
fn work_record_photo_gateway_pending_to_ready_roundtrip() {
    let pool = work_record_integration_pool();
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
            "work_record_photos/1/2/test.jpg",
            "image/jpeg",
            now,
        )
        .expect("insert pending");
    assert_eq!(WorkRecordPhotoStatus::Pending, pending.status);

    let ready = photo_gateway
        .mark_ready(seed.plan_id, created.id, pending.id, 128, 0, now)
        .expect("mark ready");
    assert_eq!(WorkRecordPhotoStatus::Ready, ready.status);
    assert_eq!(Some(0), ready.position);
    assert_eq!(Some(128), ready.byte_size);

    let listed = photo_gateway
        .list_ready_for_plan(seed.plan_id, &[created.id])
        .expect("list");
    assert_eq!(1, listed.len());
    assert_eq!(pending.id, listed[0].id);
}

#[test]
fn work_record_photo_gateway_deletes_stale_pending_rows() {
    let pool = work_record_integration_pool();
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
                name: "古い pending".into(),
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
            "work_record_photos/10/1/stale.jpg",
            "image/jpeg",
            now,
        )
        .expect("insert pending");

    pool.with_write(|conn| {
        conn.execute(
            "UPDATE work_record_photos \
             SET created_at = datetime('now', '-2 hours'), updated_at = datetime('now', '-2 hours') \
             WHERE id = ?1",
            rusqlite::params![pending.id],
        )
    })
    .expect("age pending row");

    let removed = photo_gateway
        .delete_stale_pending_older_than(
            seed.plan_id,
            created.id,
            now - time::Duration::minutes(30),
        )
        .expect("delete stale pending");
    assert_eq!(removed.len(), 1);
    assert_eq!(removed[0].id, pending.id);
}

#[test]
fn insert_pending_under_limit_rejects_fourth_photo() {
    let pool = work_record_integration_pool();
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
                name: "上限テスト".into(),
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

    for index in 0..MAX_PHOTOS_PER_RECORD {
        let storage_key =
            format!("work_record_photos/{}/{}/pending-{index}.jpg", seed.plan_id, created.id);
        let inserted = photo_gateway
            .insert_pending_under_limit(
                seed.plan_id,
                created.id,
                &storage_key,
                "image/jpeg",
                MAX_PHOTOS_PER_RECORD,
                now,
            )
            .expect("insert under limit");
        assert!(inserted.is_some(), "photo {index} should insert");
    }

    let overflow_key =
        format!("work_record_photos/{}/{}/overflow.jpg", seed.plan_id, created.id);
    let rejected = photo_gateway
        .insert_pending_under_limit(
            seed.plan_id,
            created.id,
            &overflow_key,
            "image/jpeg",
            MAX_PHOTOS_PER_RECORD,
            now,
        )
        .expect("insert under limit");
    assert!(rejected.is_none());
}

#[test]
fn mark_ready_under_limit_assigns_next_position_and_rejects_overflow() {
    let pool = work_record_integration_pool();
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
                name: "完了上限テスト".into(),
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

    let mut pending_ids = Vec::new();
    for index in 0..MAX_PHOTOS_PER_RECORD {
        let storage_key =
            format!("work_record_photos/{}/{}/complete-{index}.jpg", seed.plan_id, created.id);
        let pending = photo_gateway
            .insert_pending_under_limit(
                seed.plan_id,
                created.id,
                &storage_key,
                "image/jpeg",
                MAX_PHOTOS_PER_RECORD,
                now,
            )
            .expect("insert pending")
            .expect("slot available");
        pending_ids.push(pending.id);
    }

    for (position, photo_id) in pending_ids.iter().enumerate() {
        let ready = photo_gateway
            .mark_ready_under_limit(
                seed.plan_id,
                created.id,
                *photo_id,
                100 + position as i64,
                MAX_PHOTOS_PER_RECORD,
                now,
            )
            .expect("mark ready under limit")
            .expect("ready slot available");
        assert_eq!(WorkRecordPhotoStatus::Ready, ready.status);
        assert_eq!(Some(position as i32), ready.position);
    }

    let overflow_key =
        format!("work_record_photos/{}/{}/overflow-pending.jpg", seed.plan_id, created.id);
    let overflow_pending = photo_gateway
        .insert_pending_under_limit(
            seed.plan_id,
            created.id,
            &overflow_key,
            "image/jpeg",
            MAX_PHOTOS_PER_RECORD,
            now,
        )
        .expect("insert pending");
    assert!(overflow_pending.is_none());
}

#[test]
fn touch_pending_updated_at_prevents_stale_cleanup_after_content_upload() {
    let pool = work_record_integration_pool();
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
                name: "touch テスト".into(),
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
            "work_record_photos/10/1/touched.jpg",
            "image/jpeg",
            now,
        )
        .expect("insert pending");

    pool.with_write(|conn| {
        conn.execute(
            "UPDATE work_record_photos SET created_at = datetime('now', '-2 hours') WHERE id = ?1",
            rusqlite::params![pending.id],
        )
    })
    .expect("age created_at only");

    photo_gateway
        .touch_pending_updated_at(seed.plan_id, created.id, pending.id, now)
        .expect("touch pending");

    let removed = photo_gateway
        .delete_stale_pending_older_than(
            seed.plan_id,
            created.id,
            now - time::Duration::minutes(30),
        )
        .expect("delete stale pending");
    assert!(removed.is_empty());
}
