// Tests for `mappers/plan_vs_actual_mapper.rs`.

use crate::cultivation_plan::dtos::task_schedule_timeline_snapshot::{
    TaskScheduleTimelinePlanRead, TaskScheduleTimelineScheduleItemRead,
    TaskScheduleTimelineScheduleRead, TaskScheduleTimelineSnapshot,
    TaskScheduleTimelineFieldRead, TaskScheduleTimelineWorkRecordSummaryRead,
};
use crate::cultivation_plan::mappers::plan_vs_actual_mapper::PlanVsActualMapper;
use crate::cultivation_plan::policies::plan_variance_threshold_policy::VarianceExceedanceKind;
use time::Date;

fn sample_item(
    id: i64,
    scheduled_date: Option<&str>,
    actual_date: Option<&str>,
    gdd_trigger: Option<f64>,
    gdd_at_actual: Option<f64>,
    status: &str,
) -> TaskScheduleTimelineScheduleItemRead {
    sample_item_with_stage(id, scheduled_date, actual_date, gdd_trigger, gdd_at_actual, status, None, None)
}

fn sample_item_with_stage(
    id: i64,
    scheduled_date: Option<&str>,
    actual_date: Option<&str>,
    gdd_trigger: Option<f64>,
    gdd_at_actual: Option<f64>,
    status: &str,
    stage_order: Option<i32>,
    stage_name: Option<&str>,
) -> TaskScheduleTimelineScheduleItemRead {
    sample_item_with_work_record(
        id,
        scheduled_date,
        actual_date,
        gdd_trigger,
        gdd_at_actual,
        status,
        stage_order,
        stage_name,
        None,
        None,
    )
}

fn sample_item_with_work_record(
    id: i64,
    scheduled_date: Option<&str>,
    actual_date: Option<&str>,
    gdd_trigger: Option<f64>,
    gdd_at_actual: Option<f64>,
    status: &str,
    stage_order: Option<i32>,
    stage_name: Option<&str>,
    fertilize_id: Option<i64>,
    pesticide_id: Option<i64>,
) -> TaskScheduleTimelineScheduleItemRead {
    let work_records = actual_date
        .map(|date| vec![TaskScheduleTimelineWorkRecordSummaryRead {
            id: id * 10,
            actual_date: date.to_string(),
            notes: None,
            gdd_at_actual,
            amount: None,
            amount_unit: None,
            fertilize_id,
            pesticide_id,
        }])
        .unwrap_or_default();

    TaskScheduleTimelineScheduleItemRead {
        id,
        name: format!("Task {id}"),
        task_type: "field_work".into(),
        scheduled_date: scheduled_date.map(str::to_string),
        stage_name: stage_name.map(str::to_string),
        stage_order,
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
    sample_snapshot_with_category("general", items)
}

fn sample_snapshot_with_category(
    category: &str,
    items: Vec<TaskScheduleTimelineScheduleItemRead>,
) -> TaskScheduleTimelineSnapshot {
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
                category: category.into(),
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
    assert_eq!(1, summary.action_required_items.len());
    assert_eq!(1, summary.action_required_items[0].item_id);
    assert_eq!(
        VarianceExceedanceKind::Days,
        summary.action_required_items[0].exceedance_kind
    );
}

#[test]
fn summary_includes_blueprint_timing_adjustment_proposals_per_crop_category() {
    let snapshot = sample_snapshot(vec![
        sample_item(1, Some("2026-06-01"), Some("2026-06-08"), Some(100.0), Some(110.0), "planned"),
        sample_item(2, Some("2026-06-02"), Some("2026-06-04"), Some(100.0), Some(108.0), "planned"),
    ]);

    let summary = PlanVsActualMapper::summary_from_snapshot(&snapshot, 5);

    assert_eq!(1, summary.blueprint_timing_adjustment_proposals.len());
    let proposal = &summary.blueprint_timing_adjustment_proposals[0];
    assert_eq!(42, proposal.crop_id);
    assert_eq!("Tomato", proposal.crop_name);
    assert_eq!("general", proposal.category);
    assert_eq!(2, proposal.recorded_item_count);
    assert!((proposal.average_delta_days - 4.5).abs() < f64::EPSILON);
    assert!(proposal.average_gdd_delta.is_some());
}

#[test]
fn blueprint_timing_proposals_skip_small_variance() {
    let snapshot = sample_snapshot(vec![
        sample_item(1, Some("2026-06-01"), Some("2026-06-01"), Some(100.0), Some(100.0), "planned"),
    ]);

    let summary = PlanVsActualMapper::summary_from_snapshot(&snapshot, 5);

    assert!(summary.blueprint_timing_adjustment_proposals.is_empty());
}

#[test]
fn summary_includes_blueprint_amount_adjustment_proposals_per_crop_category_and_task_type() {
    let snapshot = TaskScheduleTimelineSnapshot {
        plan: sample_snapshot(vec![]).plan,
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
                category: "fertilizer".into(),
                items: vec![
                    sample_item_with_amounts(
                        1,
                        "fertilizer",
                        "fertilize",
                        Some(1),
                        Some("Vegetative"),
                        Some(2.0),
                        Some(3.0),
                        Some("kg"),
                    ),
                    sample_item_with_amounts(
                        2,
                        "fertilizer",
                        "fertilize",
                        Some(1),
                        Some("Vegetative"),
                        Some(2.0),
                        Some(2.0),
                        Some("kg"),
                    ),
                ],
            }],
        }],
        scheduled_dates: vec![Date::parse(
            "2026-06-02",
            &time::format_description::well_known::Iso8601::DATE,
        )
        .expect("date")],
    };

    let summary = PlanVsActualMapper::summary_from_snapshot(&snapshot, 5);

    assert_eq!(1, summary.blueprint_amount_adjustment_proposals.len());
    let proposal = &summary.blueprint_amount_adjustment_proposals[0];
    assert_eq!(42, proposal.crop_id);
    assert_eq!("Tomato", proposal.crop_name);
    assert_eq!("fertilizer", proposal.category);
    assert_eq!("fertilize", proposal.task_type);
    assert_eq!(2, proposal.recorded_item_count);
    assert!((proposal.average_amount_delta - 0.5).abs() < f64::EPSILON);
    assert_eq!(Some("kg"), proposal.amount_unit.as_deref());
}

#[test]
fn blueprint_amount_proposals_separate_by_stage_order_for_same_crop_category_and_task_type() {
    let snapshot = TaskScheduleTimelineSnapshot {
        plan: sample_snapshot(vec![]).plan,
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
                category: "fertilizer".into(),
                items: vec![
                    sample_item_with_amounts(
                        1,
                        "fertilizer",
                        "fertilize",
                        Some(1),
                        Some("Vegetative"),
                        Some(2.0),
                        Some(3.0),
                        Some("kg"),
                    ),
                    sample_item_with_amounts(
                        2,
                        "fertilizer",
                        "fertilize",
                        Some(2),
                        Some("Flowering"),
                        Some(2.0),
                        Some(3.0),
                        Some("kg"),
                    ),
                ],
            }],
        }],
        scheduled_dates: vec![Date::parse(
            "2026-06-02",
            &time::format_description::well_known::Iso8601::DATE,
        )
        .expect("date")],
    };

    let summary = PlanVsActualMapper::summary_from_snapshot(&snapshot, 5);

    assert_eq!(2, summary.blueprint_amount_adjustment_proposals.len());
    let stage_one = summary
        .blueprint_amount_adjustment_proposals
        .iter()
        .find(|proposal| proposal.stage_order == Some(1))
        .expect("stage 1 proposal");
    let stage_two = summary
        .blueprint_amount_adjustment_proposals
        .iter()
        .find(|proposal| proposal.stage_order == Some(2))
        .expect("stage 2 proposal");
    assert_eq!(42, stage_one.crop_id);
    assert_eq!("fertilize", stage_one.task_type);
    assert!((stage_one.average_amount_delta - 1.0).abs() < f64::EPSILON);
    assert_eq!(Some("Vegetative"), stage_one.stage_name.as_deref());
    assert!((stage_two.average_amount_delta - 1.0).abs() < f64::EPSILON);
    assert_eq!(Some("Flowering"), stage_two.stage_name.as_deref());
}

#[test]
fn blueprint_amount_proposals_skip_small_variance() {
    let snapshot = TaskScheduleTimelineSnapshot {
        plan: sample_snapshot(vec![]).plan,
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
                category: "fertilizer".into(),
                items: vec![sample_item_with_amounts(
                    1,
                    "fertilizer",
                    "fertilize",
                    Some(1),
                    Some("Vegetative"),
                    Some(2.0),
                    Some(2.25),
                    Some("kg"),
                )],
            }],
        }],
        scheduled_dates: vec![Date::parse(
            "2026-06-02",
            &time::format_description::well_known::Iso8601::DATE,
        )
        .expect("date")],
    };

    let summary = PlanVsActualMapper::summary_from_snapshot(&snapshot, 5);

    assert!(summary.blueprint_amount_adjustment_proposals.is_empty());
}

#[test]
fn pest_control_amount_proposals_use_lower_category_threshold() {
    let snapshot = TaskScheduleTimelineSnapshot {
        plan: sample_snapshot(vec![]).plan,
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
                category: "pest_control".into(),
                items: vec![sample_item_with_amounts(
                    1,
                    "pest_control",
                    "preventive_spray",
                    Some(1),
                    Some("Vegetative"),
                    Some(1.0),
                    Some(1.35),
                    Some("L"),
                )],
            }],
        }],
        scheduled_dates: vec![Date::parse(
            "2026-06-02",
            &time::format_description::well_known::Iso8601::DATE,
        )
        .expect("date")],
    };

    let summary = PlanVsActualMapper::summary_from_snapshot(&snapshot, 5);

    assert_eq!(1, summary.blueprint_amount_adjustment_proposals.len());
    let proposal = &summary.blueprint_amount_adjustment_proposals[0];
    assert_eq!("pest_control", proposal.category);
    assert!((proposal.average_amount_delta - 0.35).abs() < f64::EPSILON);
}

#[test]
fn stage_gdd_calibration_proposals_aggregate_by_crop_and_stage() {
    let snapshot = sample_snapshot(vec![
        sample_item_with_stage(
            1,
            Some("2026-06-01"),
            Some("2026-06-08"),
            Some(100.0),
            Some(110.0),
            "planned",
            Some(1),
            Some("Vegetative"),
        ),
        sample_item_with_stage(
            2,
            Some("2026-06-02"),
            Some("2026-06-03"),
            Some(100.0),
            Some(120.0),
            "planned",
            Some(1),
            Some("Vegetative"),
        ),
        sample_item_with_stage(
            3,
            Some("2026-06-03"),
            Some("2026-06-10"),
            Some(200.0),
            Some(205.0),
            "planned",
            Some(2),
            Some("Flowering"),
        ),
        sample_item_with_stage(
            4,
            Some("2026-06-04"),
            None,
            Some(100.0),
            None,
            "planned",
            Some(1),
            Some("Vegetative"),
        ),
    ]);

    let proposals = PlanVsActualMapper::stage_gdd_calibration_proposals_from_snapshot(&snapshot);

    assert_eq!(2, proposals.len());
    assert_eq!(42, proposals[0].crop_id);
    assert_eq!("Tomato", proposals[0].crop_name.as_str());
    assert_eq!(1, proposals[0].stage_order);
    assert_eq!("Vegetative", proposals[0].stage_name.as_str());
    assert_eq!(15.0, proposals[0].average_gdd_delta);
    assert_eq!(2, proposals[0].recorded_item_count);
    assert_eq!(2, proposals[1].stage_order);
    assert_eq!(5.0, proposals[1].average_gdd_delta);
}

#[test]
fn summary_counts_structured_unrecorded_for_fertilizer_and_pest_control_only() {
    let snapshot = TaskScheduleTimelineSnapshot {
        plan: sample_snapshot(vec![]).plan,
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
            schedules: vec![
                TaskScheduleTimelineScheduleRead {
                    category: "fertilizer".into(),
                    items: vec![
                        sample_item_with_work_record(
                            1,
                            Some("2026-06-01"),
                            Some("2026-06-02"),
                            None,
                            None,
                            "planned",
                            None,
                            None,
                            None,
                            None,
                        ),
                        sample_item_with_work_record(
                            2,
                            Some("2026-06-03"),
                            Some("2026-06-04"),
                            None,
                            None,
                            "planned",
                            None,
                            None,
                            Some(5),
                            None,
                        ),
                    ],
                },
                TaskScheduleTimelineScheduleRead {
                    category: "pest_control".into(),
                    items: vec![sample_item_with_work_record(
                        3,
                        Some("2026-06-05"),
                        Some("2026-06-06"),
                        None,
                        None,
                        "planned",
                        None,
                        None,
                        None,
                        None,
                    )],
                },
                TaskScheduleTimelineScheduleRead {
                    category: "general".into(),
                    items: vec![sample_item_with_work_record(
                        4,
                        Some("2026-06-07"),
                        Some("2026-06-08"),
                        None,
                        None,
                        "planned",
                        None,
                        None,
                        None,
                        None,
                    )],
                },
            ],
        }],
        scheduled_dates: vec![Date::parse("2026-06-02", &time::format_description::well_known::Iso8601::DATE)
            .expect("date")],
    };

    let summary = PlanVsActualMapper::summary_from_snapshot(&snapshot, 5);

    assert_eq!(2, summary.structured_unrecorded_count);
}

fn sample_item_with_amounts(
    id: i64,
    category: &str,
    task_type: &str,
    stage_order: Option<i32>,
    stage_name: Option<&str>,
    planned: Option<f64>,
    actual: Option<f64>,
    amount_unit: Option<&str>,
) -> TaskScheduleTimelineScheduleItemRead {
    let work_records = if actual.is_some() {
        vec![TaskScheduleTimelineWorkRecordSummaryRead {
            id: id * 10,
            actual_date: "2026-06-02".into(),
            notes: None,
            gdd_at_actual: None,
            amount: actual,
            amount_unit: amount_unit.map(str::to_string),
            fertilize_id: if category == "fertilizer" {
                Some(1)
            } else {
                None
            },
            pesticide_id: if category == "pest_control" {
                Some(1)
            } else {
                None
            },
        }]
    } else {
        vec![]
    };

    TaskScheduleTimelineScheduleItemRead {
        id,
        name: format!("Task {id}"),
        task_type: task_type.into(),
        scheduled_date: Some("2026-06-01".into()),
        stage_name: stage_name.map(str::to_string),
        stage_order,
        gdd_trigger: None,
        gdd_tolerance: None,
        priority: None,
        source: "agrr".into(),
        weather_dependency: None,
        time_per_sqm: None,
        amount: planned,
        amount_unit: amount_unit.map(str::to_string),
        status: "planned".into(),
        agricultural_task_id: None,
        field_cultivation_id: 100,
        agricultural_task: None,
        rescheduled_at: None,
        cancelled_at: None,
        completed: !work_records.is_empty(),
        work_records,
    }
}

#[test]
fn item_read_computes_amount_planned_actual_and_delta() {
    let item = sample_item_with_amounts(
        1,
        "fertilizer",
        "fertilize",
        Some(1),
        Some("Vegetative"),
        Some(2.0),
        Some(2.5),
        Some("kg"),
    );
    let read = PlanVsActualMapper::item_read(&item, "fertilizer");

    assert_eq!(Some(2.0), read.amount_planned);
    assert_eq!(Some(2.5), read.amount_actual);
    assert_eq!(Some(0.5), read.amount_delta);
    assert_eq!(Some("kg"), read.amount_unit.as_deref());
}

#[test]
fn summary_aggregates_average_amount_delta_by_category_stage_and_task_type() {
    let snapshot = TaskScheduleTimelineSnapshot {
        plan: sample_snapshot(vec![]).plan,
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
            schedules: vec![
                TaskScheduleTimelineScheduleRead {
                    category: "fertilizer".into(),
                    items: vec![
                        sample_item_with_amounts(
                            1,
                            "fertilizer",
                            "fertilize",
                            Some(1),
                            Some("Vegetative"),
                            Some(2.0),
                            Some(2.5),
                            Some("kg"),
                        ),
                        sample_item_with_amounts(
                            2,
                            "fertilizer",
                            "fertilize",
                            Some(1),
                            Some("Vegetative"),
                            Some(3.0),
                            Some(2.0),
                            Some("kg"),
                        ),
                    ],
                },
                TaskScheduleTimelineScheduleRead {
                    category: "pest_control".into(),
                    items: vec![sample_item_with_amounts(
                        3,
                        "pest_control",
                        "spray",
                        Some(2),
                        Some("Flowering"),
                        Some(1.0),
                        Some(1.5),
                        Some("L"),
                    )],
                },
                TaskScheduleTimelineScheduleRead {
                    category: "general".into(),
                    items: vec![sample_item_with_amounts(
                        4,
                        "general",
                        "field_work",
                        None,
                        None,
                        Some(5.0),
                        Some(6.0),
                        Some("h"),
                    )],
                },
            ],
        }],
        scheduled_dates: vec![Date::parse("2026-06-02", &time::format_description::well_known::Iso8601::DATE)
            .expect("date")],
    };

    let summary = PlanVsActualMapper::summary_from_snapshot(&snapshot, 5);

    assert_eq!(2, summary.amount_group_summaries.len());
    let fertilizer = summary
        .amount_group_summaries
        .iter()
        .find(|group| group.category == "fertilizer")
        .expect("fertilizer group");
    assert_eq!(Some(1), fertilizer.stage_order);
    assert_eq!("fertilize", fertilizer.task_type);
    assert_eq!(2, fertilizer.recorded_item_count);
    assert!((fertilizer.average_amount_delta.unwrap() - (-0.25)).abs() < f64::EPSILON);
    assert_eq!(Some("kg"), fertilizer.amount_unit.as_deref());

    let pest = summary
        .amount_group_summaries
        .iter()
        .find(|group| group.category == "pest_control")
        .expect("pest group");
    assert_eq!(Some(2), pest.stage_order);
    assert_eq!("spray", pest.task_type);
    assert_eq!(Some(0.5), pest.average_amount_delta);
    assert_eq!(Some("L"), pest.amount_unit.as_deref());
}

#[test]
fn summary_counts_amount_variance_and_unrecorded_amounts_for_structured_categories() {
    let snapshot = TaskScheduleTimelineSnapshot {
        plan: sample_snapshot(vec![]).plan,
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
            schedules: vec![
                TaskScheduleTimelineScheduleRead {
                    category: "fertilizer".into(),
                    items: vec![sample_item_with_amounts(
                        1,
                        "fertilizer",
                        "fertilize",
                        Some(1),
                        Some("Vegetative"),
                        Some(10.0),
                        None,
                        Some("kg"),
                    )],
                },
                TaskScheduleTimelineScheduleRead {
                    category: "pest_control".into(),
                    items: vec![sample_item_with_amounts(
                        2,
                        "pest_control",
                        "spray",
                        Some(2),
                        Some("Flowering"),
                        Some(2.0),
                        Some(3.0),
                        Some("L"),
                    )],
                },
                TaskScheduleTimelineScheduleRead {
                    category: "general".into(),
                    items: vec![sample_item_with_amounts(
                        3,
                        "general",
                        "field_work",
                        None,
                        None,
                        Some(5.0),
                        Some(6.0),
                        Some("h"),
                    )],
                },
            ],
        }],
        scheduled_dates: vec![Date::parse("2026-06-02", &time::format_description::well_known::Iso8601::DATE)
            .expect("date")],
    };

    let summary = PlanVsActualMapper::summary_from_snapshot(&snapshot, 5);

    assert_eq!(2, summary.amount_variance_count);
}
