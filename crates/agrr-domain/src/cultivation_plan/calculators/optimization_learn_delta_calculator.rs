//! Applies confirmed Learn proposal deltas onto agrr allocate crop requirements.

use std::collections::BTreeMap;

use serde_json::{json, Value};

use crate::cultivation_plan::dtos::{
    BlueprintAmountAdjustmentProposalRead, CultivationPlanCropWithAgrr, LearnHandoffStateRead,
    PlanVsActualSummaryRead, StageGddCalibrationProposalRead,
};
use crate::cultivation_plan::policies::blueprint_amount_adjustment_policy;
use crate::cultivation_plan::policies::optimization_learn_applied_proposal_policy;
use crate::weather_data::helpers::copy_and_deep_freeze;

const LEARN_BP_AMOUNT_ADJUSTMENTS_KEY: &str = "learn_optimizer_blueprint_amount_adjustments";

pub struct OptimizationLearnDeltaContext<'a> {
    pub proposal_application_progress: &'a BTreeMap<String, String>,
    pub summary: Option<&'a PlanVsActualSummaryRead>,
    pub learn_handoff: &'a LearnHandoffStateRead,
    pub stage_id_to_order: &'a BTreeMap<(i64, i64), i32>,
}

pub struct OptimizationLearnDeltaCalculator;

impl OptimizationLearnDeltaCalculator {
    pub fn apply_to_plan_crops(
        plan_crops: Vec<CultivationPlanCropWithAgrr>,
        ctx: &OptimizationLearnDeltaContext<'_>,
    ) -> Vec<CultivationPlanCropWithAgrr> {
        if ctx.proposal_application_progress.is_empty() {
            return plan_crops;
        }

        plan_crops
            .into_iter()
            .map(|crop| {
                let mut requirement = copy_and_deep_freeze(Some(crop.agrr_requirement.clone()))
                    .unwrap_or(Value::Null);
                Self::apply_stage_gdd_for_crop(
                    crop.crop_id,
                    &mut requirement,
                    ctx,
                );
                Self::apply_bp_amount_for_crop(crop.crop_id, &mut requirement, ctx);
                CultivationPlanCropWithAgrr::new(
                    crop.id,
                    crop.name,
                    crop.crop_id,
                    requirement,
                    crop.revenue_per_area,
                    crop.crop_name,
                )
            })
            .collect()
    }

    fn apply_stage_gdd_for_crop(
        crop_id: i64,
        requirement: &mut Value,
        ctx: &OptimizationLearnDeltaContext<'_>,
    ) {
        let prefix = format!("stage_gdd:{crop_id}:");
        for (key, status) in ctx.proposal_application_progress {
            if !key.starts_with(&prefix) {
                continue;
            }
            if !optimization_learn_applied_proposal_policy::qualifies_for_optimize_injection(status)
            {
                continue;
            }
            let stage_id = match key.strip_prefix(&prefix).and_then(|s| s.parse::<i64>().ok()) {
                Some(id) => id,
                None => continue,
            };
            let stage_order = ctx
                .stage_id_to_order
                .get(&(crop_id, stage_id))
                .copied();
            let Some(stage_order) = stage_order else {
                continue;
            };
            let target_gdd = Self::target_required_gdd(
                crop_id,
                stage_id,
                stage_order,
                requirement,
                ctx,
            );
            let Some(target_gdd) = target_gdd else {
                continue;
            };
            Self::set_stage_required_gdd(requirement, stage_order, target_gdd);
        }
    }

    fn target_required_gdd(
        crop_id: i64,
        stage_id: i64,
        stage_order: i32,
        requirement: &Value,
        ctx: &OptimizationLearnDeltaContext<'_>,
    ) -> Option<f64> {
        if let Some(applied) =
            Self::handoff_applied_required_gdd(ctx.learn_handoff, crop_id, stage_id)
        {
            return Some(applied);
        }
        // Bulk/inline apply updates crop master before marking confirmed. Without a
        // matching handoff absolute value, keep the live master requirement unchanged.
        let _ = (stage_order, requirement, ctx);
        None
    }

    fn handoff_applied_required_gdd(
        handoff: &LearnHandoffStateRead,
        crop_id: i64,
        stage_id: i64,
    ) -> Option<f64> {
        let payload = handoff.post_master_payload.as_ref()?;
        let kind = payload.get("kind").and_then(|v| v.as_str())?;
        if kind != "stage_gdd" {
            return None;
        }
        let payload_crop_id = payload.get("cropId").and_then(|v| v.as_i64())?;
        let payload_stage_id = payload.get("stageId").and_then(|v| v.as_i64())?;
        if payload_crop_id != crop_id || payload_stage_id != stage_id {
            return None;
        }
        payload
            .get("appliedRequiredGdd")
            .and_then(|v| v.as_f64())
            .map(round_gdd)
    }

    fn apply_bp_amount_for_crop(
        crop_id: i64,
        requirement: &mut Value,
        ctx: &OptimizationLearnDeltaContext<'_>,
    ) {
        let prefix = format!("bp_amount:{crop_id}:");
        let mut adjustments = Vec::new();

        for (key, status) in ctx.proposal_application_progress {
            if !key.starts_with(&prefix) {
                continue;
            }
            if !optimization_learn_applied_proposal_policy::qualifies_for_optimize_injection(status)
            {
                continue;
            }
            let Some(parsed) = Self::parse_bp_amount_key(key) else {
                continue;
            };
            if parsed.crop_id != crop_id {
                continue;
            }
            let Some(proposal) = Self::bp_amount_proposal_from_summary(
                ctx.summary,
                crop_id,
                &parsed.category,
                &parsed.task_type,
                parsed.stage_order,
            ) else {
                continue;
            };
            adjustments.push(Self::bp_amount_adjustment_json(&parsed, proposal));
        }

        if adjustments.is_empty() {
            return;
        }

        if let Some(crop_obj) = requirement.get_mut("crop").and_then(|v| v.as_object_mut()) {
            crop_obj.insert(
                LEARN_BP_AMOUNT_ADJUSTMENTS_KEY.into(),
                Value::Array(adjustments),
            );
        }
    }

    fn parse_bp_amount_key(key: &str) -> Option<BpAmountKeyParts> {
        let rest = key.strip_prefix("bp_amount:")?;
        let mut segments = rest.splitn(4, ':');
        let crop_id = segments.next()?.parse().ok()?;
        let category = segments.next()?.to_string();
        let task_type = segments.next()?.to_string();
        let stage_segment = segments.next()?;
        let stage_order = if stage_segment == "null" {
            None
        } else {
            Some(stage_segment.parse().ok()?)
        };
        Some(BpAmountKeyParts {
            crop_id,
            category,
            task_type,
            stage_order,
        })
    }

    fn bp_amount_proposal_from_summary<'a>(
        summary: Option<&'a PlanVsActualSummaryRead>,
        crop_id: i64,
        category: &str,
        task_type: &str,
        stage_order: Option<i32>,
    ) -> Option<&'a BlueprintAmountAdjustmentProposalRead> {
        let summary = summary?;
        summary.blueprint_amount_adjustment_proposals.iter().find(|p| {
            p.crop_id == crop_id
                && p.category == category
                && p.task_type == task_type
                && p.stage_order == stage_order
        })
    }

    fn bp_amount_adjustment_json(
        key: &BpAmountKeyParts,
        proposal: &BlueprintAmountAdjustmentProposalRead,
    ) -> Value {
        json!({
            "category": key.category,
            "task_type": key.task_type,
            "stage_order": key.stage_order,
            "average_amount_delta": proposal.average_amount_delta,
            "amount_unit": proposal.amount_unit,
            "proposal_progress_key": blueprint_amount_adjustment_policy::proposal_progress_key(
                key.crop_id,
                &key.category,
                &key.task_type,
                key.stage_order,
            ),
        })
    }

    fn stage_required_gdd(requirement: &Value, stage_order: i32) -> Option<f64> {
        requirement
            .get("stage_requirements")?
            .as_array()?
            .iter()
            .find(|stage| {
                stage
                    .get("stage")
                    .and_then(|s| s.get("order"))
                    .and_then(|o| o.as_i64())
                    == Some(i64::from(stage_order))
            })
            .and_then(|stage| {
                stage
                    .get("thermal")
                    .and_then(|t| t.get("required_gdd"))
                    .and_then(|g| g.as_f64())
            })
    }

    fn set_stage_required_gdd(requirement: &mut Value, stage_order: i32, target_gdd: f64) {
        let Some(stages) = requirement
            .get_mut("stage_requirements")
            .and_then(|v| v.as_array_mut())
        else {
            return;
        };
        for stage in stages {
            let matches = stage
                .get("stage")
                .and_then(|s| s.get("order"))
                .and_then(|o| o.as_i64())
                == Some(i64::from(stage_order));
            if !matches {
                continue;
            }
            if let Some(thermal) = stage.get_mut("thermal") {
                if let Some(obj) = thermal.as_object_mut() {
                    obj.insert("required_gdd".into(), json!(target_gdd));
                }
            }
        }
    }
}

struct BpAmountKeyParts {
    crop_id: i64,
    category: String,
    task_type: String,
    stage_order: Option<i32>,
}

fn round_gdd(value: f64) -> f64 {
    (value * 10.0).round() / 10.0
}

#[cfg(test)]
mod calculators_optimization_learn_delta_calculator_test_inline {
    use super::*;
    use crate::cultivation_plan::dtos::CultivationPlanCropWithAgrr;
    use serde_json::json;

    fn sample_requirement(required_gdd: f64) -> Value {
        json!({
            "crop": { "crop_id": "1", "name": "Crop1", "max_revenue": 1000.0, "groups": [] },
            "stage_requirements": [{
                "stage": { "name": "Stage1", "order": 1 },
                "temperature": { "base_temperature": 10.0, "max_temperature": 50.0 },
                "thermal": { "required_gdd": required_gdd }
            }]
        })
    }

    fn sample_crop(required_gdd: f64) -> CultivationPlanCropWithAgrr {
        CultivationPlanCropWithAgrr::new(
            1,
            String::from("cpc-1"),
            1,
            sample_requirement(required_gdd),
            Some(5000.0),
            String::from("Crop1"),
        )
    }

    #[test]
    fn confirmed_stage_gdd_calibration_updates_required_gdd_when_handoff_records_applied_value() {
        let mut progress = BTreeMap::new();
        progress.insert("stage_gdd:1:2".into(), "confirmed".into());

        let mut stage_id_to_order = BTreeMap::new();
        stage_id_to_order.insert((1, 2), 1);

        let summary = PlanVsActualSummaryRead {
            plan_id: 9,
            unrecorded_count: 0,
            structured_unrecorded_count: 0,
            amount_variance_count: 0,
            categories: vec![],
            amount_group_summaries: vec![],
            top_variance_items: vec![],
            stage_gdd_calibration_proposals: vec![StageGddCalibrationProposalRead {
                crop_id: 1,
                crop_name: "Crop1".into(),
                stage_order: 1,
                stage_name: "Stage1".into(),
                average_gdd_delta: 12.5,
                recorded_item_count: 2,
            }],
            action_required_items: vec![],
            blueprint_timing_adjustment_proposals: vec![],
            blueprint_amount_adjustment_proposals: vec![],
        };

        let handoff = LearnHandoffStateRead {
            post_master_payload: Some(json!({
                "kind": "stage_gdd",
                "cropId": 1,
                "stageId": 2,
                "appliedRequiredGdd": 112.5
            })),
            ..Default::default()
        };

        let ctx = OptimizationLearnDeltaContext {
            proposal_application_progress: &progress,
            summary: Some(&summary),
            learn_handoff: &handoff,
            stage_id_to_order: &stage_id_to_order,
        };

        let out =
            OptimizationLearnDeltaCalculator::apply_to_plan_crops(vec![sample_crop(100.0)], &ctx);
        let gdd = out[0].agrr_requirement["stage_requirements"][0]["thermal"]["required_gdd"]
            .as_f64()
            .unwrap();
        assert!((gdd - 112.5).abs() < 0.001);
    }

    #[test]
    fn confirmed_stage_gdd_without_handoff_keeps_live_master_requirement() {
        let mut progress = BTreeMap::new();
        progress.insert("stage_gdd:1:2".into(), "confirmed".into());

        let mut stage_id_to_order = BTreeMap::new();
        stage_id_to_order.insert((1, 2), 1);

        let summary = PlanVsActualSummaryRead {
            plan_id: 9,
            unrecorded_count: 0,
            structured_unrecorded_count: 0,
            amount_variance_count: 0,
            categories: vec![],
            amount_group_summaries: vec![],
            top_variance_items: vec![],
            stage_gdd_calibration_proposals: vec![StageGddCalibrationProposalRead {
                crop_id: 1,
                crop_name: "Crop1".into(),
                stage_order: 1,
                stage_name: "Stage1".into(),
                average_gdd_delta: 12.5,
                recorded_item_count: 2,
            }],
            action_required_items: vec![],
            blueprint_timing_adjustment_proposals: vec![],
            blueprint_amount_adjustment_proposals: vec![],
        };

        let ctx = OptimizationLearnDeltaContext {
            proposal_application_progress: &progress,
            summary: Some(&summary),
            learn_handoff: &LearnHandoffStateRead::default(),
            stage_id_to_order: &stage_id_to_order,
        };

        let out =
            OptimizationLearnDeltaCalculator::apply_to_plan_crops(vec![sample_crop(112.5)], &ctx);
        let gdd = out[0].agrr_requirement["stage_requirements"][0]["thermal"]["required_gdd"]
            .as_f64()
            .unwrap();
        assert!(
            (gdd - 112.5).abs() < 0.001,
            "expected live master GDD without handoff double-apply (got {gdd})"
        );
    }

    #[test]
    fn confirmed_bp_amount_adjustment_is_visible_in_allocate_input() {
        let mut progress = BTreeMap::new();
        progress.insert(
            "bp_amount:1:fertilizer:fertilize:1".into(),
            "confirmed".into(),
        );

        let summary = PlanVsActualSummaryRead {
            plan_id: 9,
            unrecorded_count: 0,
            structured_unrecorded_count: 0,
            amount_variance_count: 0,
            categories: vec![],
            amount_group_summaries: vec![],
            top_variance_items: vec![],
            stage_gdd_calibration_proposals: vec![],
            action_required_items: vec![],
            blueprint_timing_adjustment_proposals: vec![],
            blueprint_amount_adjustment_proposals: vec![BlueprintAmountAdjustmentProposalRead {
                crop_id: 1,
                crop_name: "Crop1".into(),
                category: "fertilizer".into(),
                task_type: "fertilize".into(),
                stage_order: Some(1),
                stage_name: Some("Stage1".into()),
                average_amount_delta: 3.5,
                recorded_item_count: 1,
                amount_unit: Some("kg".into()),
            }],
        };

        let ctx = OptimizationLearnDeltaContext {
            proposal_application_progress: &progress,
            summary: Some(&summary),
            learn_handoff: &LearnHandoffStateRead::default(),
            stage_id_to_order: &BTreeMap::new(),
        };

        let out = OptimizationLearnDeltaCalculator::apply_to_plan_crops(vec![sample_crop(100.0)], &ctx);
        let adjustments = &out[0].agrr_requirement["crop"][LEARN_BP_AMOUNT_ADJUSTMENTS_KEY];
        assert!(adjustments.is_array());
        assert_eq!(adjustments[0]["average_amount_delta"], 3.5);
        assert_eq!(adjustments[0]["category"], "fertilizer");
    }

    #[test]
    fn dismissed_proposals_do_not_mutate_allocate_input() {
        let mut progress = BTreeMap::new();
        progress.insert("stage_gdd:1:2".into(), "dismissed".into());

        let mut stage_id_to_order = BTreeMap::new();
        stage_id_to_order.insert((1, 2), 1);

        let summary = PlanVsActualSummaryRead {
            plan_id: 9,
            unrecorded_count: 0,
            structured_unrecorded_count: 0,
            amount_variance_count: 0,
            categories: vec![],
            amount_group_summaries: vec![],
            top_variance_items: vec![],
            stage_gdd_calibration_proposals: vec![StageGddCalibrationProposalRead {
                crop_id: 1,
                crop_name: "Crop1".into(),
                stage_order: 1,
                stage_name: "Stage1".into(),
                average_gdd_delta: 12.5,
                recorded_item_count: 2,
            }],
            action_required_items: vec![],
            blueprint_timing_adjustment_proposals: vec![],
            blueprint_amount_adjustment_proposals: vec![],
        };

        let ctx = OptimizationLearnDeltaContext {
            proposal_application_progress: &progress,
            summary: Some(&summary),
            learn_handoff: &LearnHandoffStateRead::default(),
            stage_id_to_order: &stage_id_to_order,
        };

        let out =
            OptimizationLearnDeltaCalculator::apply_to_plan_crops(vec![sample_crop(100.0)], &ctx);
        let gdd = out[0].agrr_requirement["stage_requirements"][0]["thermal"]["required_gdd"]
            .as_f64()
            .unwrap();
        assert!((gdd - 100.0).abs() < 0.001);
    }

    #[test]
    fn handoff_applied_required_gdd_prevents_double_apply_when_master_already_updated() {
        let mut progress = BTreeMap::new();
        progress.insert("stage_gdd:1:2".into(), "confirmed".into());

        let mut stage_id_to_order = BTreeMap::new();
        stage_id_to_order.insert((1, 2), 1);

        let summary = PlanVsActualSummaryRead {
            plan_id: 9,
            unrecorded_count: 0,
            structured_unrecorded_count: 0,
            amount_variance_count: 0,
            categories: vec![],
            amount_group_summaries: vec![],
            top_variance_items: vec![],
            stage_gdd_calibration_proposals: vec![StageGddCalibrationProposalRead {
                crop_id: 1,
                crop_name: "Crop1".into(),
                stage_order: 1,
                stage_name: "Stage1".into(),
                average_gdd_delta: 12.5,
                recorded_item_count: 2,
            }],
            action_required_items: vec![],
            blueprint_timing_adjustment_proposals: vec![],
            blueprint_amount_adjustment_proposals: vec![],
        };

        let handoff = LearnHandoffStateRead {
            post_master_payload: Some(json!({
                "kind": "stage_gdd",
                "cropId": 1,
                "stageId": 2,
                "appliedRequiredGdd": 112.5
            })),
            ..Default::default()
        };

        let ctx = OptimizationLearnDeltaContext {
            proposal_application_progress: &progress,
            summary: Some(&summary),
            learn_handoff: &handoff,
            stage_id_to_order: &stage_id_to_order,
        };

        let out = OptimizationLearnDeltaCalculator::apply_to_plan_crops(
            vec![sample_crop(112.5)],
            &ctx,
        );
        let gdd = out[0].agrr_requirement["stage_requirements"][0]["thermal"]["required_gdd"]
            .as_f64()
            .unwrap();
        assert!(
            (gdd - 112.5).abs() < 0.001,
            "expected handoff absolute value, not current+delta double apply (got {gdd})"
        );
    }

    #[test]
    fn handoff_applied_required_gdd_takes_precedence_over_summary_delta() {
        let mut progress = BTreeMap::new();
        progress.insert("stage_gdd:1:2".into(), "confirmed".into());

        let mut stage_id_to_order = BTreeMap::new();
        stage_id_to_order.insert((1, 2), 1);

        let summary = PlanVsActualSummaryRead {
            plan_id: 9,
            unrecorded_count: 0,
            structured_unrecorded_count: 0,
            amount_variance_count: 0,
            categories: vec![],
            amount_group_summaries: vec![],
            top_variance_items: vec![],
            stage_gdd_calibration_proposals: vec![StageGddCalibrationProposalRead {
                crop_id: 1,
                crop_name: "Crop1".into(),
                stage_order: 1,
                stage_name: "Stage1".into(),
                average_gdd_delta: 12.5,
                recorded_item_count: 2,
            }],
            action_required_items: vec![],
            blueprint_timing_adjustment_proposals: vec![],
            blueprint_amount_adjustment_proposals: vec![],
        };

        let handoff = LearnHandoffStateRead {
            post_master_payload: Some(json!({
                "kind": "stage_gdd",
                "cropId": 1,
                "stageId": 2,
                "appliedRequiredGdd": 140.0
            })),
            ..Default::default()
        };

        let ctx = OptimizationLearnDeltaContext {
            proposal_application_progress: &progress,
            summary: Some(&summary),
            learn_handoff: &handoff,
            stage_id_to_order: &stage_id_to_order,
        };

        let out =
            OptimizationLearnDeltaCalculator::apply_to_plan_crops(vec![sample_crop(100.0)], &ctx);
        let gdd = out[0].agrr_requirement["stage_requirements"][0]["thermal"]["required_gdd"]
            .as_f64()
            .unwrap();
        assert!((gdd - 140.0).abs() < 0.001);
    }
}
