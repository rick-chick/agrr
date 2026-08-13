//! Computes plan-vs-actual deltas from task schedule timeline snapshot rows.

use crate::cultivation_plan::dtos::plan_vs_actual::{
    PlanVsActualCategorySummaryRead, PlanVsActualItemRead, PlanVsActualSummaryRead,
    StageGddCalibrationProposalRead,
};
use crate::cultivation_plan::dtos::task_schedule_timeline_snapshot::{
    TaskScheduleTimelineScheduleItemRead, TaskScheduleTimelineSnapshot,
};
use time::{format_description::well_known::Iso8601, Date};

pub const DEFAULT_TOP_VARIANCE_LIMIT: usize = 5;

pub struct PlanVsActualMapper;

impl PlanVsActualMapper {
    pub fn item_read(
        item: &TaskScheduleTimelineScheduleItemRead,
        category: &str,
    ) -> PlanVsActualItemRead {
        let actual_date = primary_actual_date(item);
        let scheduled_date = item.scheduled_date.clone();
        let delta_days = delta_days_between(&scheduled_date, &actual_date);
        let gdd_at_actual = primary_gdd_at_actual(item);
        let gdd_trigger = item.gdd_trigger;
        let gdd_delta = gdd_delta_between(gdd_trigger, gdd_at_actual);

        PlanVsActualItemRead {
            item_id: item.id,
            field_cultivation_id: item.field_cultivation_id,
            category: category.to_string(),
            name: item.name.clone(),
            scheduled_date,
            actual_date,
            delta_days,
            gdd_trigger,
            gdd_at_actual,
            gdd_delta,
        }
    }

    pub fn summary_from_snapshot(
        snapshot: &TaskScheduleTimelineSnapshot,
        top_n: usize,
    ) -> PlanVsActualSummaryRead {
        let mut items = Vec::new();
        for field in &snapshot.fields {
            for schedule in &field.schedules {
                for item in &schedule.items {
                    if !counts_toward_summary(item) {
                        continue;
                    }
                    items.push(Self::item_read(item, schedule.category.as_str()));
                }
            }
        }

        let unrecorded_count = items
            .iter()
            .filter(|row| row.scheduled_date.is_some() && row.actual_date.is_none())
            .count() as i64;

        let categories = category_summaries(&items);
        let top_variance_items = top_variance(&items, top_n);
        let stage_gdd_calibration_proposals =
            stage_gdd_calibration_proposals_from_snapshot(snapshot);

        PlanVsActualSummaryRead {
            plan_id: snapshot.plan.id,
            unrecorded_count,
            categories,
            top_variance_items,
            stage_gdd_calibration_proposals,
        }
    }

    pub fn stage_gdd_calibration_proposals_from_snapshot(
        snapshot: &TaskScheduleTimelineSnapshot,
    ) -> Vec<StageGddCalibrationProposalRead> {
        let mut groups: std::collections::BTreeMap<
            (i64, String, i32, String),
            Vec<f64>,
        > = std::collections::BTreeMap::new();

        for field in &snapshot.fields {
            for schedule in &field.schedules {
                for item in &schedule.items {
                    if !counts_toward_summary(item) {
                        continue;
                    }
                    let Some(stage_order) = item.stage_order else {
                        continue;
                    };
                    let stage_name = item
                        .stage_name
                        .clone()
                        .unwrap_or_else(|| format!("Stage {stage_order}"));
                    let gdd_at_actual = primary_gdd_at_actual(item);
                    let gdd_delta = gdd_delta_between(item.gdd_trigger, gdd_at_actual);
                    let Some(delta) = gdd_delta else {
                        continue;
                    };
                    groups
                        .entry((
                            field.crop_id,
                            field.crop_name.clone(),
                            stage_order,
                            stage_name,
                        ))
                        .or_default()
                        .push(delta);
                }
            }
        }

        let mut proposals: Vec<StageGddCalibrationProposalRead> = groups
            .into_iter()
            .map(|((crop_id, crop_name, stage_order, stage_name), deltas)| {
                let recorded_item_count = deltas.len() as i64;
                let average_gdd_delta = deltas.iter().sum::<f64>() / deltas.len() as f64;
                StageGddCalibrationProposalRead {
                    crop_id,
                    crop_name,
                    stage_order,
                    stage_name,
                    average_gdd_delta,
                    recorded_item_count,
                }
            })
            .collect();

        proposals.sort_by(|left, right| {
            right
                .average_gdd_delta
                .abs()
                .partial_cmp(&left.average_gdd_delta.abs())
                .unwrap_or(std::cmp::Ordering::Equal)
                .then_with(|| left.crop_id.cmp(&right.crop_id))
                .then_with(|| left.stage_order.cmp(&right.stage_order))
        });

        proposals
    }
}

fn counts_toward_summary(item: &TaskScheduleTimelineScheduleItemRead) -> bool {
    item.status != "skipped" && item.cancelled_at.is_none()
}

fn primary_actual_date(item: &TaskScheduleTimelineScheduleItemRead) -> Option<String> {
    item.work_records.first().map(|record| record.actual_date.clone())
}

fn primary_gdd_at_actual(item: &TaskScheduleTimelineScheduleItemRead) -> Option<f64> {
    item.work_records.first().and_then(|record| record.gdd_at_actual)
}

fn parse_date(value: &str) -> Option<Date> {
    Date::parse(value, &Iso8601::DATE).ok()
}

fn delta_days_between(scheduled: &Option<String>, actual: &Option<String>) -> Option<i64> {
    let scheduled = scheduled.as_deref().and_then(parse_date)?;
    let actual = actual.as_deref().and_then(parse_date)?;
    Some((actual - scheduled).whole_days())
}

fn gdd_delta_between(trigger: Option<f64>, actual: Option<f64>) -> Option<f64> {
    match (trigger, actual) {
        (Some(trigger), Some(actual)) => Some(actual - trigger),
        _ => None,
    }
}

fn category_summaries(items: &[PlanVsActualItemRead]) -> Vec<PlanVsActualCategorySummaryRead> {
    let mut by_category: std::collections::BTreeMap<String, Vec<&PlanVsActualItemRead>> =
        std::collections::BTreeMap::new();
    for item in items {
        by_category
            .entry(item.category.clone())
            .or_default()
            .push(item);
    }

    by_category
        .into_iter()
        .map(|(category, rows)| {
            let item_count = rows.len() as i64;
            let recorded = rows
                .iter()
                .filter(|row| row.actual_date.is_some())
                .collect::<Vec<_>>();
            let recorded_count = recorded.len() as i64;
            let deltas: Vec<f64> = recorded
                .iter()
                .filter_map(|row| row.delta_days.map(|days| days as f64))
                .collect();
            let average_delta_days = if deltas.is_empty() {
                None
            } else {
                Some(deltas.iter().sum::<f64>() / deltas.len() as f64)
            };
            PlanVsActualCategorySummaryRead {
                category,
                average_delta_days,
                item_count,
                recorded_count,
            }
        })
        .collect()
}

fn top_variance(items: &[PlanVsActualItemRead], top_n: usize) -> Vec<PlanVsActualItemRead> {
    let mut ranked: Vec<&PlanVsActualItemRead> = items
        .iter()
        .filter(|row| row.delta_days.is_some())
        .collect();
    ranked.sort_by(|left, right| {
        let left_abs = left.delta_days.unwrap().unsigned_abs();
        let right_abs = right.delta_days.unwrap().unsigned_abs();
        right_abs
            .cmp(&left_abs)
            .then_with(|| left.item_id.cmp(&right.item_id))
    });
    ranked
        .into_iter()
        .take(top_n)
        .cloned()
        .collect()
}

#[cfg(test)]
mod mappers_plan_vs_actual_mapper_test_inline {
    use super::*;

    include!(
        concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test/cultivation_plan/mappers_plan_vs_actual_mapper_test.rs"
        )
    );
}
