//! Ruby: `Domain::AgriculturalTask::Interactors::TaskScheduleGenerateInteractor`

use time::Date;

use crate::agricultural_task::constants::task_schedule_item_statuses::PLANNED;
use crate::agricultural_task::dtos::{
    TaskScheduleFieldMutation, TaskScheduleGenerateInput, TaskSchedulePlanMutations,
    TaskScheduleReplaceItem,
};
use crate::agricultural_task::ports::TaskScheduleGenerateInputPort;
use crate::agricultural_task::gateways::{
    CultivationPlanGateway, ProtectableScheduleItemRow, TaskScheduleBlueprint, TaskScheduleCrop,
    TaskScheduleFieldCultivation, TaskScheduleGenerationReadGateway, TaskSchedulePlan,
};
use crate::agricultural_task::gateways::{ProgressGateway, TaskScheduleGateway};
use crate::agricultural_task::mappers::{
    task_schedule_generation_context_mapper, task_schedule_item_name_mapper,
    task_schedule_protected_merge_mapper,
};
use crate::agricultural_task::mappers::task_schedule_blueprint_partition_mapper::partition_blueprints;
use crate::agricultural_task::mappers::task_schedule_progress_mapper::{
    date_for_gdd, filtered_weather_data, progress_records_from_json, safe_parse_date,
    weather_data_present, ProgressRecord,
};
use crate::agricultural_task::task_schedule_sync_error::TaskScheduleSyncError;
use crate::agricultural_task::task_schedule_sync_error_keys as sync_errors;
use crate::shared::ports::ClockPort;

pub struct TaskScheduleGenerateInteractor<'a, PG, TG, CP, RG, C> {
    progress_gateway: &'a PG,
    task_schedule_gateway: &'a TG,
    clock: &'a C,
    cultivation_plan_gateway: &'a CP,
    task_schedule_read_gateway: &'a RG,
}

impl<'a, PG, TG, CP, RG, C> TaskScheduleGenerateInteractor<'a, PG, TG, CP, RG, C>
where
    PG: ProgressGateway,
    TG: TaskScheduleGateway,
    CP: CultivationPlanGateway,
    RG: TaskScheduleGenerationReadGateway,
    C: ClockPort,
{
    pub fn new(
        progress_gateway: &'a PG,
        task_schedule_gateway: &'a TG,
        clock: &'a C,
        cultivation_plan_gateway: &'a CP,
        task_schedule_read_gateway: &'a RG,
    ) -> Self {
        Self {
            progress_gateway,
            task_schedule_gateway,
            clock,
            cultivation_plan_gateway,
            task_schedule_read_gateway,
        }
    }

    pub fn call(
        &self,
        input: TaskScheduleGenerateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let ctx = self.build_generation_context(input.cultivation_plan_id)?;
        let plan = ctx.plan;
        let protectable_items = self
            .task_schedule_read_gateway
            .list_protectable_schedule_items(plan.id)?;

        if !weather_data_present(&plan.predicted_weather_data) {
            return Err(Box::new(TaskScheduleSyncError::new(
                sync_errors::MISSING_WEATHER,
                format!(
                    "CultivationPlan#{} has no predicted weather data",
                    plan.id
                ),
            )));
        }

        let mut blueprint_cache = std::collections::HashMap::<i64, Vec<TaskScheduleBlueprint>>::new();
        let mut mutations = Vec::new();

        for field_cultivation in &plan.field_cultivations {
            self.generate_for_field(
                &plan,
                field_cultivation,
                &protectable_items,
                &mut blueprint_cache,
                &mut mutations,
            )?;
        }

        self.task_schedule_gateway.apply_plan_schedule_mutations(
            &TaskSchedulePlanMutations {
                cultivation_plan_id: plan.id,
                generated_at: self.clock.now(),
                mutations,
            },
        )?;

        Ok(())
    }

    fn build_generation_context(
        &self,
        cultivation_plan_id: i64,
    ) -> Result<crate::agricultural_task::gateways::TaskSchedulePlanContext, Box<dyn std::error::Error + Send + Sync>>
    {
        let plan_row = self
            .task_schedule_read_gateway
            .find_plan_row(cultivation_plan_id)?;
        let field_rows = self
            .task_schedule_read_gateway
            .list_field_cultivation_rows(cultivation_plan_id)?;

        if field_rows.iter().any(|row| row.crop_id.is_none()) {
            return Err(Box::new(TaskScheduleSyncError::new(
                sync_errors::MISSING_FIELD_CROP,
                format!(
                    "CultivationPlan#{} has a field without a crop assigned",
                    cultivation_plan_id
                ),
            )));
        }

        let mut crop_ids = Vec::new();
        for row in &field_rows {
            if let Some(crop_id) = row.crop_id {
                if !crop_ids.contains(&crop_id) {
                    crop_ids.push(crop_id);
                }
            }
        }

        let mut crop_rows_by_id = std::collections::HashMap::new();
        let mut blueprint_rows_by_crop_id = std::collections::HashMap::new();

        for crop_id in crop_ids {
            crop_rows_by_id.insert(
                crop_id,
                self.task_schedule_read_gateway.find_crop_row(crop_id)?,
            );
            blueprint_rows_by_crop_id.insert(
                crop_id,
                self.task_schedule_read_gateway
                    .list_crop_task_schedule_blueprint_rows(crop_id)?,
            );
        }

        Ok(task_schedule_generation_context_mapper::assemble(
            plan_row,
            field_rows,
            crop_rows_by_id,
            blueprint_rows_by_crop_id,
        ))
    }

    fn generate_for_field(
        &self,
        plan: &TaskSchedulePlan,
        field_cultivation: &TaskScheduleFieldCultivation,
        protectable_items: &[ProtectableScheduleItemRow],
        blueprint_cache: &mut std::collections::HashMap<i64, Vec<TaskScheduleBlueprint>>,
        mutations: &mut Vec<TaskScheduleFieldMutation>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let crop = match &field_cultivation.crop {
            Some(c) => c,
            None => return Ok(()),
        };

        let blueprints = self.blueprints_for(crop, blueprint_cache);
        if blueprints.is_empty() {
            return Err(Box::new(TaskScheduleSyncError::with_crop_id(
                sync_errors::MISSING_CROP_BLUEPRINTS,
                format!(
                    "Crop#{} ({}) has no task schedule blueprints",
                    crop.id, crop.name
                ),
                crop.id,
            )));
        }

        let (general_blueprints, fertilizer_blueprints) = partition_blueprints(blueprints.as_slice());
        if general_blueprints.is_empty() {
            return Err(Box::new(TaskScheduleSyncError::with_crop_id(
                sync_errors::MISSING_GENERAL_BLUEPRINTS,
                format!(
                    "Crop#{} ({}) has no general work blueprints",
                    crop.id, crop.name
                ),
                crop.id,
            )));
        }

        let start_date = field_cultivation
            .start_date
            .or(plan.calculated_planning_start_date);
        let filtered_weather = filtered_weather_data(&plan.predicted_weather_data, start_date);
        let progress_data = self.progress_gateway.calculate_progress(
            crop,
            start_date,
            &filtered_weather,
        )?;

        let mut progress_records = progress_records_from_json(&progress_data);
        if let Some(start) = start_date {
            let filtered: Vec<_> = progress_records
                .iter()
                .filter(|record| {
                    safe_parse_date(&record.date)
                        .map(|d| d >= start)
                        .unwrap_or(false)
                })
                .cloned()
                .collect();
            if !filtered.is_empty() {
                progress_records = filtered;
            }
        }

        if progress_records.is_empty() {
            return Err(Box::new(TaskScheduleSyncError::with_crop_id(
                sync_errors::EMPTY_GDD_PROGRESS,
                format!(
                    "progress records empty for cultivation_plan_id={}",
                    plan.id
                ),
                crop.id,
            )));
        }

        self.create_schedule(
            plan,
            field_cultivation,
            protectable_items,
            "general",
            mutations,
            || {
                general_blueprints
                    .iter()
                    .map(|blueprint| {
                        self.item_attributes_for_blueprint(
                            blueprint,
                            &progress_records,
                            field_cultivation.start_date,
                            crop.id,
                        )
                    })
                    .collect::<Result<Vec<_>, _>>()
            },
        )?;

        if !fertilizer_blueprints.is_empty() {
            self.create_schedule(
                plan,
                field_cultivation,
                protectable_items,
                "fertilizer",
                mutations,
                || {
                    fertilizer_blueprints
                        .iter()
                        .map(|blueprint| {
                            self.item_attributes_for_blueprint(
                                blueprint,
                                &progress_records,
                                field_cultivation.start_date,
                                crop.id,
                            )
                        })
                        .collect::<Result<Vec<_>, _>>()
                },
            )?;
        } else {
            self.clear_schedule(
                plan,
                field_cultivation,
                protectable_items,
                "fertilizer",
                mutations,
            )?;
        }

        Ok(())
    }

    fn blueprints_for(
        &self,
        crop: &TaskScheduleCrop,
        cache: &mut std::collections::HashMap<i64, Vec<TaskScheduleBlueprint>>,
    ) -> Vec<TaskScheduleBlueprint> {
        if !cache.contains_key(&crop.id) {
            cache.insert(crop.id, crop.crop_task_schedule_blueprints.clone());
        }
        cache.get(&crop.id).cloned().unwrap_or_default()
    }

    fn item_attributes_for_blueprint(
        &self,
        blueprint: &TaskScheduleBlueprint,
        progress_records: &[ProgressRecord],
        fallback_start_date: Option<Date>,
        crop_id: i64,
    ) -> Result<TaskScheduleReplaceItem, Box<dyn std::error::Error + Send + Sync>> {
        let gdd_trigger = blueprint.gdd_trigger.ok_or_else(|| {
            Box::new(TaskScheduleSyncError::with_crop_id(
                sync_errors::MISSING_GDD_TRIGGER,
                "blueprint gdd_trigger is missing",
                crop_id,
            )) as Box<dyn std::error::Error + Send + Sync>
        })?;

        let task = blueprint.agricultural_task.clone();
        let scheduled_date =
            date_for_gdd(progress_records, gdd_trigger, fallback_start_date, crop_id)?;

        let description = blueprint
            .description
            .clone()
            .filter(|d| !d.trim().is_empty())
            .or_else(|| task.as_ref().and_then(|t| t.description.clone()));

        let amount_unit = blueprint
            .amount_unit
            .clone()
            .or_else(|| {
                blueprint
                    .amount
                    .map(|_| "g/m2".to_string())
            });

        Ok(TaskScheduleReplaceItem {
            task_type: blueprint.task_type.clone(),
            agricultural_task_id: task.as_ref().map(|t| t.id),
            name: task_schedule_item_name_mapper::name_for_blueprint(blueprint, task.as_ref()),
            description,
            stage_name: blueprint.stage_name.clone(),
            stage_order: blueprint.stage_order,
            gdd_trigger,
            gdd_tolerance: blueprint.gdd_tolerance,
            scheduled_date,
            priority: blueprint.priority,
            source: blueprint.source.clone(),
            status: PLANNED.to_string(),
            weather_dependency: blueprint
                .weather_dependency
                .clone()
                .or_else(|| task.as_ref().and_then(|t| t.weather_dependency.clone())),
            time_per_sqm: blueprint
                .time_per_sqm
                .or_else(|| task.as_ref().and_then(|t| t.time_per_sqm)),
            amount: blueprint.amount,
            amount_unit,
        })
    }

    fn create_schedule<F>(
        &self,
        plan: &TaskSchedulePlan,
        field_cultivation: &TaskScheduleFieldCultivation,
        protectable_items: &[ProtectableScheduleItemRow],
        category: &str,
        mutations: &mut Vec<TaskScheduleFieldMutation>,
        items_fn: F,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>
    where
        F: FnOnce() -> Result<Vec<TaskScheduleReplaceItem>, Box<dyn std::error::Error + Send + Sync>>,
    {
        let _ = plan;
        let items = items_fn()?;
        let merge_result = task_schedule_protected_merge_mapper::merge_protected_items(
            protectable_items,
            field_cultivation.id,
            category,
            items,
        );
        mutations.push(TaskScheduleFieldMutation::MergeReplace {
            field_cultivation_id: field_cultivation.id,
            category: category.to_string(),
            preserved_item_ids: merge_result.preserved_item_ids,
            items_to_insert: merge_result.items_to_insert,
        });
        Ok(())
    }

    fn clear_schedule(
        &self,
        plan: &TaskSchedulePlan,
        field_cultivation: &TaskScheduleFieldCultivation,
        protectable_items: &[ProtectableScheduleItemRow],
        category: &str,
        mutations: &mut Vec<TaskScheduleFieldMutation>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let _ = plan;
        let merge_result = task_schedule_protected_merge_mapper::merge_protected_items(
            protectable_items,
            field_cultivation.id,
            category,
            Vec::new(),
        );
        if merge_result.preserved_item_ids.is_empty() {
            mutations.push(TaskScheduleFieldMutation::DeleteAll {
                field_cultivation_id: field_cultivation.id,
                category: category.to_string(),
            });
        } else {
            mutations.push(TaskScheduleFieldMutation::MergeReplace {
                field_cultivation_id: field_cultivation.id,
                category: category.to_string(),
                preserved_item_ids: merge_result.preserved_item_ids,
                items_to_insert: merge_result.items_to_insert,
            });
        }
        Ok(())
    }
}

impl<PG, TG, CP, RG, C> TaskScheduleGenerateInputPort
    for TaskScheduleGenerateInteractor<'_, PG, TG, CP, RG, C>
where
    PG: ProgressGateway,
    TG: TaskScheduleGateway,
    CP: CultivationPlanGateway,
    RG: TaskScheduleGenerationReadGateway,
    C: ClockPort,
{
    fn call(
        &self,
        input: TaskScheduleGenerateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        TaskScheduleGenerateInteractor::call(self, input)
    }
}

#[cfg(test)]
mod interactors_task_schedule_generate_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/agricultural_task/interactors_task_schedule_generate_interactor_test.rs"));
}
