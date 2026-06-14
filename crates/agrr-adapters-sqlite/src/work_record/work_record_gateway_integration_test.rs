//! Integration: work record gateway CRUD roundtrip with plan + schedule + item fixture.

use super::task_schedule_item_lookup_gateway::TaskScheduleItemLookupSqliteGateway;
use super::work_record_gateway::WorkRecordSqliteGateway;
use super::work_record_integration_fixture::{seed_work_record_crud, work_record_integration_pool};
use agrr_domain::shared::exceptions::RecordNotFoundError;
use agrr_domain::work_record::dtos::{WorkRecordListInput, WorkRecordUpdateInput};
use agrr_domain::work_record::gateways::{
    TaskScheduleItemLookupGateway, WorkRecordCreatePersistAttrs, WorkRecordGateway,
};
use rust_decimal::Decimal;
use std::str::FromStr;
use time::{Date, OffsetDateTime};

fn sample_create_attrs(
    seed: &super::work_record_integration_fixture::WorkRecordCrudSeed,
) -> WorkRecordCreatePersistAttrs {
    let now = OffsetDateTime::now_utc();
    WorkRecordCreatePersistAttrs {
        field_cultivation_id: Some(seed.field_cultivation_id),
        task_schedule_item_id: Some(seed.task_schedule_item_id),
        agricultural_task_id: Some(seed.agricultural_task_id),
        name: "除草作業".into(),
        task_type: Some("field_work".into()),
        actual_date: Date::from_calendar_date(2026, time::Month::June, 12).unwrap(),
        amount: Decimal::from_str("2.5").ok(),
        amount_unit: Some("kg".into()),
        time_spent_minutes: Some(45),
        notes: Some("午前に実施".into()),
        created_at: now,
        updated_at: now,
    }
}

#[test]
fn work_record_gateway_crud_roundtrip() {
    let pool = work_record_integration_pool();
    let seed = seed_work_record_crud(&pool);
    let gateway = WorkRecordSqliteGateway::new(pool.clone());
    let lookup = TaskScheduleItemLookupSqliteGateway::new(pool.clone());

    let prefill = lookup
        .find_item_for_plan(seed.plan_id, seed.task_schedule_item_id)
        .expect("schedule item lookup");
    assert_eq!(seed.plan_id, prefill.cultivation_plan_id);
    assert_eq!("除草作業", prefill.name);

    let created = gateway
        .create(seed.plan_id, sample_create_attrs(&seed))
        .expect("create");
    assert!(created.id > 0);
    assert_eq!(seed.plan_id, created.cultivation_plan_id);
    assert_eq!(Some(seed.task_schedule_item_id), created.task_schedule_item_id);
    assert_eq!("除草作業", created.name);
    assert!(created.task_schedule_item.is_some());

    let found = gateway
        .find_for_plan(seed.plan_id, created.id)
        .expect("find");
    assert_eq!(created.id, found.id);
    assert_eq!(created.notes, found.notes);

    let listed = gateway
        .list_for_plan(
            seed.plan_id,
            &WorkRecordListInput {
                from: Some(Date::from_calendar_date(2026, time::Month::June, 1).unwrap()),
                to: Some(Date::from_calendar_date(2026, time::Month::June, 30).unwrap()),
                field_cultivation_id: Some(seed.field_cultivation_id),
            },
        )
        .expect("list");
    assert_eq!(1, listed.len());
    assert_eq!(created.id, listed[0].id);

    let updated = gateway
        .update(
            seed.plan_id,
            created.id,
            &WorkRecordUpdateInput {
                notes: Some("修正メモ".into()),
                time_spent_minutes: Some(60),
                ..Default::default()
            },
            OffsetDateTime::now_utc(),
        )
        .expect("update");
    assert_eq!(Some("修正メモ".into()), updated.notes);
    assert_eq!(Some(60), updated.time_spent_minutes);

    gateway
        .destroy(seed.plan_id, created.id)
        .expect("destroy");

    let err = gateway
        .find_for_plan(seed.plan_id, created.id)
        .expect_err("deleted record should not be found");
    assert!(err.downcast_ref::<RecordNotFoundError>().is_some());
}
