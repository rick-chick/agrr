//! Ruby: `Domain::CultivationPlan::Mappers::PlanAllocationAdjustAgrrPayloadMapper`

use std::collections::BTreeMap;

use serde_json::Value;

use crate::cultivation_plan::calculators::{
    agrr_crops_config_calculator::{self, AgrrCropConfigEntry, AgrrCropsConfigLogger},
    agrr_fields_config_calculator::{self, AgrrPlanFieldRow},
    agrr_interaction_rules_calculator,
};
use crate::cultivation_plan::dtos::PlanAllocationAdjustReadSnapshot;
use crate::cultivation_plan::mappers::agrr_adjust_allocation_row_mapper;
use crate::shared::ports::LoggerPort;

pub struct CropsConfigLogger<'a, L: LoggerPort>(pub &'a L);

impl<L: LoggerPort> agrr_crops_config_calculator::AgrrCropsConfigLogger for CropsConfigLogger<'_, L> {
    fn warn(&self, message: &str) {
        self.0.warn(message);
    }
}

pub struct PlanAllocationAdjustAgrrPayloadMapper;

impl PlanAllocationAdjustAgrrPayloadMapper {
    pub fn to_current_allocation<L: LoggerPort>(
        snapshot: &PlanAllocationAdjustReadSnapshot,
        exclude_ids: &[i64],
        logger: &L,
    ) -> Value
    where
        L: LoggerPort,
    {
        let field_cultivation_count: usize = snapshot
            .field_source_snapshots
            .iter()
            .map(|f| f.cultivations.len())
            .sum();
        logger.info(&format!(
            "🔍 [Build Allocation] field_cultivations count: {field_cultivation_count}"
        ));
        if !exclude_ids.is_empty() {
            logger.info(&format!("🔍 [Build Allocation] exclude_ids: {exclude_ids:?}"));
        }

        agrr_adjust_allocation_row_mapper::build_current_allocation(
            snapshot.plan_id,
            &snapshot.field_source_snapshots,
            exclude_ids,
        )
    }

    pub fn to_fields_config(snapshot: &PlanAllocationAdjustReadSnapshot) -> Vec<Value> {
        let plan_fields: Vec<AgrrPlanFieldRow> = snapshot
            .plan_field_snapshots
            .iter()
            .map(|field| AgrrPlanFieldRow {
                id: field.id.to_string(),
                name: field.name.clone(),
                area: field.area,
                daily_fixed_cost: Some(field.daily_fixed_cost),
            })
            .collect();

        agrr_fields_config_calculator::build(&plan_fields)
    }

    pub fn to_crops_config(
        snapshot: &PlanAllocationAdjustReadSnapshot,
        logger: Option<&dyn AgrrCropsConfigLogger>,
    ) -> Vec<Value> {
        let entries: Vec<AgrrCropConfigEntry> = snapshot
            .plan_crop_snapshots
            .iter()
            .map(|entry| AgrrCropConfigEntry {
                crop_id: entry.crop_id.to_string(),
                crop_name: entry.crop_name.clone(),
                has_growth_stages: entry.has_growth_stages,
                requirement: entry.agrr_requirement.clone(),
            })
            .collect();

        agrr_crops_config_calculator::build(&entries, logger)
    }

    pub fn to_interaction_rules(
        snapshot: &PlanAllocationAdjustReadSnapshot,
        random_hex: &str,
    ) -> Vec<Value> {
        let mut crop_groups: BTreeMap<String, Vec<String>> = BTreeMap::new();
        for entry in &snapshot.plan_crop_snapshots {
            let groups: Vec<String> = entry
                .groups
                .as_array()
                .map(|arr| {
                    arr.iter()
                        .filter_map(|v| v.as_str().map(str::to_string))
                        .collect()
                })
                .unwrap_or_default();
            crop_groups.insert(entry.crop_id.to_string(), groups);
        }

        agrr_interaction_rules_calculator::build(&crop_groups, random_hex)
    }
}
