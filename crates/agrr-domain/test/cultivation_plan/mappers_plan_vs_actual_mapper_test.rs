// Tests for `mappers/plan_vs_actual_mapper.rs`.

use crate::cultivation_plan::dtos::task_schedule_timeline_snapshot::{
    TaskScheduleTimelinePlanRead, TaskScheduleTimelineScheduleItemRead,
    TaskScheduleTimelineScheduleRead, TaskScheduleTimelineSnapshot,
    TaskScheduleTimelineFieldRead, TaskScheduleTimelineWorkRecordSummaryRead,
};
use crate::cultivation_plan::mappers::plan_vs_actual_mapper::PlanVsActualMapper;
use time::Date;

fn sample_item(
    id: i64,
    scheduled_date: Option<&str>,
    actual_date: Option<&str>,
    gdd_trigger: Option<f64>,
    gdd_at_actual: Option<f64>,
    status: &str,
) -> TaskScheduleTimelineScheduleItemRead {
    let work_records = actual_date
        .map(|date| vec![TaskScheduleTimelineWorkRecordSummaryRead {
            id: id * 10,
            actual_date: date.to_string(),
            notes: None,
            gdd_at_actual,
        }])
        .unwrap_or_default();

    TaskScheduleTimelineScheduleItemRead {
        id,
        name: format!("Task {id}"),
        task_type: "field_work".into(),
        scheduled_date: scheduled_date.map(str::to_string),
        stage_name: None,
        stage_order: None,
        gdd_trigger,
        gdd_tolerance: None,
        priority: None,
        source: "agrr".into(),
        weather_dependency: None,
        time_per_sqm: None,
        amount: None,
        amount_unit: None,
        status: status.into(),
        agricultural_task_id: None,
        field_cultivation_id: 100,
        agricultural_task: None,
        rescheduled_at: None,
        cancelled_at: None,
        completed: !work_records.is_empty(),
        work_records,
    }
}

fn sample_snapshot(items: Vec<TaskScheduleTimelineScheduleItemRead>) -> TaskScheduleTimelineSnapshot {
    TaskScheduleTimelineSnapshot {
        plan: TaskScheduleTimelinePlanRead {
            id: 1,
            display_name: "Plan".into(),
            status: "completed".into(),
            planning_start_date: None,
            planning_end_date: None,
            timeline_generated_at: None,
            farm_display_name: "Farm".into(),
            total_area: 50.0,
            task_schedule_sync_state: "ready".into(),
            task_schedule_sync_error: None,
            task_schedule_sync_error_crop_id: None,
        },
        fields: vec![TaskScheduleTimelineFieldRead {
            id: 10,
            name: "F1".into(),
            crop_name: "Tomato".into(),
            area_sqm: 50.0,
            field_cultivation_id: 100,
            crop_id: 42,
            cultivation_start_date: None,
            cultivation_end_date: None,
            task_options: vec![],
            schedules: vec![TaskScheduleTimelineScheduleRead {
                category: "general".into(),
                items,
            }],
        }],
        scheduled_dates: vec![Date::parse("2026-06-02", &time::format_description::well_known::Iso8601::DATE)
            .expect("date")],
    }
}

#[test]
fn item_read_computes_delta_days_and_gdd_delta() {
    let item = sample_item(
        1,
        Some("2026-06-02"),
        Some("2026-06-08"),
        Some(120.0),
        Some(130.5),
        "planned",
    );
    let read = PlanVsActualMapper::item_read(&item, "general");

    assert_eq!(Some("2026-06-02"), read.scheduled_date.as_deref());
    assert_eq!(Some("2026-06-08"), read.actual_date.as_deref());
    assert_eq!(Some(6), read.delta_days);
    assert_eq!(Some(120.0), read.gdd_trigger);
    assert_eq!(Some(130.5), read.gdd_at_actual);
    assert_eq!(Some(10.5), read.gdd_delta);
}

#[test]
fn item_read_allows_null_gdd_at_actual() {
    let item = sample_item(
        2,
        Some("2026-06-02"),
        Some("2026-06-03"),
        Some(120.0),
        None,
        "planned",
    );
    let read = PlanVsActualMapper::item_read(&item, "general");

    assert_eq!(Some(1), read.delta_days);
    assert_eq!(None, read.gdd_at_actual);
    assert_eq!(None, read.gdd_delta);
}

#[test]
fn summary_counts_unrecorded_and_top_variance() {
    let snapshot = sample_snapshot(vec![
        sample_item(1, Some("2026-06-01"), Some("2026-06-08"), Some(100.0), Some(110.0), "planned"),
        sample_item(2, Some("2026-06-02"), Some("2026-06-03"), Some(100.0), Some(105.0), "planned"),
        sample_item(3, Some("2026-06-03"), None, Some(100.0), None, "planned"),
        sample_item(4, Some("2026-06-04"), None, None, None, "skipped"),
    ]);

    let summary = PlanVsActualMapper::summary_from_snapshot(&snapshot, 2);

    assert_eq!(1, summary.plan_id);
    assert_eq!(1, summary.unrecorded_count);
    assert_eq!(1, summary.categories.len());
    assert_eq!("general", summary.categories[0].category);
    assert_eq!(Some(4.0), summary.categories[0].average_delta_days);
    assert_eq!(3, summary.categories[0].item_count);
    assert_eq!(2, summary.categories[0].recorded_count);
    assert_eq!(2, summary.top_variance_items.len());
    assert_eq!(1, summary.top_variance_items[0].item_id);
    assert_eq!(Some(7), summary.top_variance_items[0].delta_days);
}
