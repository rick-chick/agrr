//! Integration tests for task schedule item prefill lookup (work record create).

use super::task_schedule_item_lookup_gateway::TaskScheduleItemLookupSqliteGateway;
use super::work_record_integration_fixture::{seed_work_record_crud, work_record_integration_pool};
use agrr_domain::work_record::gateways::TaskScheduleItemLookupGateway;
use rust_decimal::Decimal;
use std::str::FromStr;

#[test]
fn find_item_for_plan_returns_prefill_snapshot() {
    let pool = work_record_integration_pool();
    let seed = seed_work_record_crud(&pool);
    let gateway = TaskScheduleItemLookupSqliteGateway::new(pool);

    let snapshot = gateway
        .find_item_for_plan(seed.plan_id, seed.task_schedule_item_id)
        .expect("lookup");

    assert_eq!(snapshot.cultivation_plan_id, seed.plan_id);
    assert_eq!(snapshot.field_cultivation_id, Some(seed.field_cultivation_id));
    assert_eq!(snapshot.agricultural_task_id, Some(seed.agricultural_task_id));
    assert_eq!(snapshot.name, "除草作業");
    assert_eq!(snapshot.task_type, Some("field_work".into()));
    assert_eq!(
        snapshot.scheduled_date.map(|d| d.to_string()),
        Some("2026-06-02".into())
    );
    assert_eq!(
        snapshot.amount,
        Some(Decimal::from_str("2.5").expect("decimal"))
    );
    assert_eq!(snapshot.amount_unit.as_deref(), Some("kg"));
}

#[test]
fn find_item_for_plan_errors_when_item_not_in_plan() {
    let pool = work_record_integration_pool();
    let seed = seed_work_record_crud(&pool);
    let gateway = TaskScheduleItemLookupSqliteGateway::new(pool);

    let err = gateway
        .find_item_for_plan(seed.plan_id, 99_999)
        .expect_err("missing item");
    assert!(!err.to_string().is_empty());
}
