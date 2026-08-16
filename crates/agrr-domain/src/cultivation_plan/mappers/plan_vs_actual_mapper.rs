//! Computes plan-vs-actual deltas from task schedule timeline snapshot rows.

use crate::cultivation_plan::dtos::plan_vs_actual::{
    BlueprintTimingAdjustmentProposalRead, PlanVarianceActionItemRead,
    PlanVsActualAmountDeltaSummaryRead, PlanVsActualCategorySummaryRead, PlanVsActualItemRead,
    PlanVsActualSummaryRead, StageGddCalibrationProposalRead,
};
use crate::cultivation_plan::dtos::task_schedule_timeline_snapshot::{
    TaskScheduleTimelineScheduleItemRead, TaskScheduleTimelineSnapshot,
    TaskScheduleTimelineWorkRecordSummaryRead,
};
use crate::cultivation_plan::policies::blueprint_timing_adjustment_policy::qualifies_for_proposal;
use crate::cultivation_plan::policies::plan_variance_threshold_policy::exceedance_kind;
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
        let amount_planned = item.amount;
        let amount_actual = primary_amount_actual(item);
        let amount_delta = amount_delta_between(amount_planned, amount_actual);
        let amount_unit = item
            .amount_unit
            .clone()
            .or_else(|| primary_amount_unit(item));

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
            amount_planned,
            amount_actual,
            amount_delta,
            amount_unit,
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

        let structured_unrecorded_count = structured_unrecorded_count_from_snapshot(snapshot);

        let categories = category_summaries(&items);
        let top_variance_items = top_variance(&items, top_n);
        let stage_gdd_calibration_proposals =
            Self::stage_gdd_calibration_proposals_from_snapshot(snapshot);
        let action_required_items = action_required(&items);
        let blueprint_timing_adjustment_proposals =
            Self::blueprint_timing_adjustment_proposals_from_snapshot(snapshot);
        let amount_delta_summaries = amount_delta_summaries_from_snapshot(snapshot);

        PlanVsActualSummaryRead {
            plan_id: snapshot.plan.id,
            unrecorded_count,
            structured_unrecorded_count,
            categories,
            top_variance_items,
            stage_gdd_calibration_proposals,
            action_required_items,
            blueprint_timing_adjustment_proposals,
            amount_delta_summaries,
        }
    }

    pub fn stage_gdd_calibration_proposals_from_snapshot(
        snapshot: &TaskScheduleTimelineSnapshot,
    ) -> Vec<StageGddCalibrationProposalRead> {
        let mut groups: std::collections::BTreeMap<(i64, String, i32, String), Vec<f64>> =
            std::collections::BTreeMap::new();

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

    pub fn blueprint_timing_adjustment_proposals_from_snapshot(
        snapshot: &TaskScheduleTimelineSnapshot,
    ) -> Vec<BlueprintTimingAdjustmentProposalRead> {
        let mut groups: std::collections::BTreeMap<
            (i64, String, String),
            (Vec<f64>, Vec<f64>),
        > = std::collections::BTreeMap::new();

        for field in &snapshot.fields {
            for schedule in &field.schedules {
                for item in &schedule.items {
                    if !counts_toward_summary(item) {
                        continue;
                    }
                    let Some(delta_days) =
                        Self::item_read(item, schedule.category.as_str()).delta_days
                    else {
                        continue;
                    };
                    let gdd_delta =
                        gdd_delta_between(item.gdd_trigger, primary_gdd_at_actual(item));
                    let entry = groups
                        .entry((
                            field.crop_id,
                            field.crop_name.clone(),
                            schedule.category.clone(),
                        ))
                        .or_insert((Vec::new(), Vec::new()));
                    entry.0.push(delta_days as f64);
                    if let Some(delta) = gdd_delta {
                        entry.1.push(delta);
                    }
                }
            }
        }

        let mut proposals: Vec<BlueprintTimingAdjustmentProposalRead> = groups
            .into_iter()
            .filter_map(|((crop_id, crop_name, category), (day_deltas, gdd_deltas))| {
                let recorded_item_count = day_deltas.len() as i64;
                let average_delta_days = day_deltas.iter().sum::<f64>() / day_deltas.len() as f64;
                if !qualifies_for_proposal(average_delta_days, recorded_item_count) {
                    return None;
                }
                let average_gdd_delta = if gdd_deltas.is_empty() {
                    None
                } else {
                    Some(gdd_deltas.iter().sum::<f64>() / gdd_deltas.len() as f64)
                };
                Some(BlueprintTimingAdjustmentProposalRead {
                    crop_id,
                    crop_name,
                    category,
                    average_delta_days,
                    average_gdd_delta,
                    recorded_item_count,
                })
            })
            .collect();

        proposals.sort_by(|left, right| {
            right
                .average_delta_days
                .abs()
                .partial_cmp(&left.average_delta_days.abs())
                .unwrap_or(std::cmp::Ordering::Equal)
                .then_with(|| left.crop_id.cmp(&right.crop_id))
                .then_with(|| left.category.cmp(&right.category))
        });

        proposals
    }
}

fn counts_toward_summary(item: &TaskScheduleTimelineScheduleItemRead) -> bool {
    item.status != "skipped" && item.cancelled_at.is_none()
}

fn structured_unrecorded_count_from_snapshot(snapshot: &TaskScheduleTimelineSnapshot) -> i64 {
    let mut count = 0_i64;
    for field in &snapshot.fields {
        for schedule in &field.schedules {
            if !is_structured_input_category(schedule.category.as_str()) {
                continue;
            }
            for item in &schedule.items {
                if !counts_toward_summary(item) {
                    continue;
                }
                for record in &item.work_records {
                    if is_structured_unrecorded_work_record(schedule.category.as_str(), record) {
                        count += 1;
                    }
                }
            }
        }
    }
    count
}

fn is_structured_input_category(category: &str) -> bool {
    matches!(category, "fertilizer" | "pest_control")
}

fn is_structured_unrecorded_work_record(
    category: &str,
    record: &TaskScheduleTimelineWorkRecordSummaryRead,
) -> bool {
    match category {
        "fertilizer" => record.fertilize_id.is_none(),
        "pest_control" => record.pesticide_id.is_none(),
        _ => false,
    }
}

fn primary_actual_date(item: &TaskScheduleTimelineScheduleItemRead) -> Option<String> {
    item.work_records
        .first()
        .map(|record| record.actual_date.clone())
}

fn primary_gdd_at_actual(item: &TaskScheduleTimelineScheduleItemRead) -> Option<f64> {
    item.work_records
        .first()
        .and_then(|record| record.gdd_at_actual)
}

fn primary_amount_actual(item: &TaskScheduleTimelineScheduleItemRead) -> Option<f64> {
    item.work_records.first().and_then(|record| record.amount)
}

fn primary_amount_unit(item: &TaskScheduleTimelineScheduleItemRead) -> Option<String> {
    item.work_records
        .first()
        .and_then(|record| record.amount_unit.clone())
}

fn amount_delta_between(planned: Option<f64>, actual: Option<f64>) -> Option<f64> {
    match (planned, actual) {
        (Some(planned), Some(actual)) => Some(actual - planned),
        _ => None,
    }
}

fn amount_delta_summaries_from_snapshot(
    snapshot: &TaskScheduleTimelineSnapshot,
) -> Vec<PlanVsActualAmountDeltaSummaryRead> {
    let mut groups: std::collections::BTreeMap<
        (String, Option<i32>, Option<String>, String),
        (Vec<f64>, Option<String>),
    > = std::collections::BTreeMap::new();

    for field in &snapshot.fields {
        for schedule in &field.schedules {
            if !is_amount_tracked_category(schedule.category.as_str()) {
                continue;
            }
            for item in &schedule.items {
                if !counts_toward_summary(item) {
                    continue;
                }
                let read = PlanVsActualMapper::item_read(item, schedule.category.as_str());
                let Some(delta) = read.amount_delta else {
                    continue;
                };
                let key = (
                    schedule.category.clone(),
                    item.stage_order,
                    item.stage_name.clone(),
                    item.task_type.clone(),
                );
                let entry = groups.entry(key).or_insert((Vec::new(), read.amount_unit.clone()));
                entry.0.push(delta);
                if entry.1.is_none() {
                    entry.1 = read.amount_unit.clone();
                }
            }
        }
    }

    let mut summaries: Vec<PlanVsActualAmountDeltaSummaryRead> = groups
        .into_iter()
        .map(|((category, stage_order, stage_name, task_type), (deltas, amount_unit))| {
            let recorded_item_count = deltas.len() as i64;
            let average_amount_delta = deltas.iter().sum::<f64>() / deltas.len() as f64;
            PlanVsActualAmountDeltaSummaryRead {
                category,
                stage_order,
                stage_name,
                task_type,
                average_amount_delta,
                recorded_item_count,
                amount_unit,
            }
        })
        .collect();

    summaries.sort_by(|left, right| {
        left.category
            .cmp(&right.category)
            .then_with(|| left.stage_order.cmp(&right.stage_order))
            .then_with(|| left.task_type.cmp(&right.task_type))
    });

    summaries
}

fn is_amount_tracked_category(category: &str) -> bool {
    matches!(category, "fertilizer" | "pest_control")
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

fn action_required(items: &[PlanVsActualItemRead]) -> Vec<PlanVarianceActionItemRead> {
    let mut required: Vec<PlanVarianceActionItemRead> = items
        .iter()
        .filter_map(|item| {
            exceedance_kind(item).map(|kind| PlanVarianceActionItemRead::from_item(item, kind))
        })
        .collect();
    required.sort_by(|left, right| {
        let left_days = left.delta_days.map(|days| days.unsigned_abs()).unwrap_or(0);
        let right_days = right.delta_days.map(|days| days.unsigned_abs()).unwrap_or(0);
        right_days
            .cmp(&left_days)
            .then_with(|| left.item_id.cmp(&right.item_id))
    });
    required
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
