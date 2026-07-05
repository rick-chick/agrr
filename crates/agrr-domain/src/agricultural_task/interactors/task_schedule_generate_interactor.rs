//! Ruby: `Domain::AgriculturalTask::Interactors::TaskScheduleGenerateInteractor`

use rust_decimal::Decimal;
use time::Date;

use crate::agricultural_task::constants::schedule_item_types::{
    BASAL_FERTILIZATION, FIELD_WORK, TOPDRESS_FERTILIZATION,
};
use crate::agricultural_task::constants::task_schedule_item_statuses::PLANNED;
use crate::agricultural_task::dtos::{TaskScheduleGenerateInput, TaskScheduleReplaceItem};
use crate::agricultural_task::ports::TaskScheduleGenerateInputPort;
use crate::agricultural_task::gateways::{
    CultivationPlanGateway, TaskScheduleBlueprint, TaskScheduleCrop,
    TaskScheduleFieldCultivation, TaskScheduleGenerationReadGateway, TaskSchedulePlan,
};
use crate::agricultural_task::gateways::{ProgressGateway, TaskScheduleGateway};
use crate::agricultural_task::mappers::{
    task_schedule_generation_context_mapper, task_schedule_item_name_mapper,
};
use crate::agricultural_task::task_schedule_sync_error::TaskScheduleSyncError;
use crate::agricultural_task::task_schedule_sync_error_keys as sync_errors;
use crate::shared::helpers::deep_dup;
use crate::shared::ports::ClockPort;
use crate::shared::type_converters::cast_big_decimal_json;

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

        self.cultivation_plan_gateway.within_transaction(|| {
            for field_cultivation in &plan.field_cultivations {
                self.generate_for_field(&plan, field_cultivation, &mut blueprint_cache)?;
            }
            Ok::<(), Box<dyn std::error::Error + Send + Sync>>(())
        })?;

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
        blueprint_cache: &mut std::collections::HashMap<i64, Vec<TaskScheduleBlueprint>>,
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
            return Err(Box::new(TaskScheduleSyncError::new(
                sync_errors::EMPTY_GDD_PROGRESS,
                format!(
                    "progress records empty for cultivation_plan_id={}",
                    plan.id
                ),
            )));
        }

        self.create_schedule(plan, field_cultivation, "general", || {
            general_blueprints
                .iter()
                .map(|blueprint| {
                    self.item_attributes_for_blueprint(
                        blueprint,
                        &progress_records,
                        field_cultivation.start_date,
                    )
                })
                .collect::<Result<Vec<_>, _>>()
        })?;

        if !fertilizer_blueprints.is_empty() {
            self.create_schedule(plan, field_cultivation, "fertilizer", || {
                fertilizer_blueprints
                    .iter()
                    .map(|blueprint| {
                        self.item_attributes_for_blueprint(
                            blueprint,
                            &progress_records,
                            field_cultivation.start_date,
                        )
                    })
                    .collect::<Result<Vec<_>, _>>()
            })?;
        } else {
            self.clear_schedule(plan, field_cultivation, "fertilizer")?;
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
    ) -> Result<TaskScheduleReplaceItem, Box<dyn std::error::Error + Send + Sync>> {
        let gdd_trigger = blueprint.gdd_trigger.ok_or_else(|| {
            Box::new(TaskScheduleSyncError::new(
                sync_errors::MISSING_GDD_TRIGGER,
                "blueprint gdd_trigger is missing",
            )) as Box<dyn std::error::Error + Send + Sync>
        })?;

        let task = blueprint.agricultural_task.clone();
        let scheduled_date =
            date_for_gdd(progress_records, gdd_trigger, fallback_start_date)?;

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
        category: &str,
        items_fn: F,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>
    where
        F: FnOnce() -> Result<Vec<TaskScheduleReplaceItem>, Box<dyn std::error::Error + Send + Sync>>,
    {
        let items = items_fn()?;
        self.task_schedule_gateway.replace_schedule_for_field_category(
            plan.id,
            field_cultivation.id,
            category,
            self.clock.now(),
            items,
        )?;
        Ok(())
    }

    fn clear_schedule(
        &self,
        plan: &TaskSchedulePlan,
        field_cultivation: &TaskScheduleFieldCultivation,
        category: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.task_schedule_gateway.delete_all_for_field_category(
            plan.id,
            field_cultivation.id,
            category,
        )?;
        Ok(())
    }
}

#[derive(Debug, Clone)]
struct ProgressRecord {
    date: String,
    cumulative_gdd: Option<Decimal>,
}

fn weather_data_present(data: &serde_json::Value) -> bool {
    !data.is_null() && data.as_object().is_some_and(|o| !o.is_empty())
        || data.as_array().is_some_and(|a| !a.is_empty())
}

fn partition_blueprints(
    blueprints: &[TaskScheduleBlueprint],
) -> (Vec<&TaskScheduleBlueprint>, Vec<&TaskScheduleBlueprint>) {
    let mut general = Vec::new();
    let mut fertilizer = Vec::new();
    for blueprint in blueprints {
        match blueprint.task_type.as_str() {
            FIELD_WORK => general.push(blueprint),
            BASAL_FERTILIZATION | TOPDRESS_FERTILIZATION => fertilizer.push(blueprint),
            _ => {}
        }
    }
    (general, fertilizer)
}

fn progress_records_from_json(data: &serde_json::Value) -> Vec<ProgressRecord> {
    data.get("progress_records")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|record| {
                    let date = record.get("date")?.as_str()?.to_string();
                    let cumulative_gdd = cast_big_decimal_json(record.get("cumulative_gdd"));
                    Some(ProgressRecord {
                        date,
                        cumulative_gdd,
                    })
                })
                .collect()
        })
        .unwrap_or_default()
}

fn date_for_gdd(
    progress_records: &[ProgressRecord],
    target_gdd: Decimal,
    fallback_date: Option<Date>,
) -> Result<Date, Box<dyn std::error::Error + Send + Sync>> {
    for record in progress_records {
        if let Some(cumulative) = record.cumulative_gdd {
            if cumulative >= target_gdd {
                return safe_parse_date(&record.date).ok_or_else(|| {
                    Box::new(TaskScheduleSyncError::new(
                        sync_errors::GDD_DATE_NOT_FOUND,
                        format!("no date for gdd {}", target_gdd),
                    )) as Box<dyn std::error::Error + Send + Sync>
                }).or(Ok(fallback_date.unwrap_or_else(|| {
                    Date::from_calendar_date(1970, time::Month::January, 1).expect("valid")
                })));
            }
        }
    }
    if let Some(fallback) = fallback_date {
        return Ok(fallback);
    }
    Err(Box::new(TaskScheduleSyncError::new(
        sync_errors::GDD_DATE_NOT_FOUND,
        format!("no date for gdd {}", target_gdd),
    )))
}

fn safe_parse_date(value: &str) -> Option<Date> {
    let trimmed = value.trim();
    if trimmed.len() < 10 {
        return None;
    }
    let date_part = &trimmed[..10];
    let parts: Vec<&str> = date_part.split('-').collect();
    if parts.len() != 3 {
        return None;
    }
    let year: i32 = parts[0].parse().ok()?;
    let month_num: u8 = parts[1].parse().ok()?;
    let day: u8 = parts[2].parse().ok()?;
    let month = time::Month::try_from(month_num).ok()?;
    Date::from_calendar_date(year, month, day).ok()
}

fn filtered_weather_data(weather_data: &serde_json::Value, start_date: Option<Date>) -> serde_json::Value {
    let Some(start_date) = start_date else {
        return weather_data.clone();
    };
    let Some(_obj) = weather_data.as_object() else {
        return weather_data.clone();
    };

    let mut duplicated = deep_dup(weather_data);
    let data_array = duplicated
        .get("data")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();

    let filtered: Vec<serde_json::Value> = data_array
        .into_iter()
        .filter(|entry| {
            entry
                .get("time")
                .and_then(|v| v.as_str())
                .and_then(safe_parse_date)
                .map(|d| d >= start_date)
                .unwrap_or(false)
        })
        .collect();

    if !filtered.is_empty() {
        if let Some(obj) = duplicated.as_object_mut() {
            obj.insert("data".into(), serde_json::Value::Array(filtered));
        }
    }

    duplicated
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
