//! Ruby: `Domain::AgriculturalTask::Interactors::TaskScheduleGenerateInteractor`

use rust_decimal::Decimal;
use time::{Date, OffsetDateTime};

use crate::agricultural_task::constants::schedule_item_types::{
    BASAL_FERTILIZATION, FIELD_WORK, TOPDRESS_FERTILIZATION,
};
use crate::agricultural_task::constants::task_schedule_item_statuses::PLANNED;
use crate::agricultural_task::dtos::TaskScheduleReplaceItem;
use crate::agricultural_task::gateways::{
    CultivationPlanGateway, TaskScheduleBlueprint, TaskScheduleCrop, TaskScheduleFieldCultivation,
    TaskScheduleGenerationReadGateway, TaskSchedulePlan, TaskScheduleRelatedTask,
};
use crate::agricultural_task::gateways::{ProgressGateway, TaskScheduleGateway};
use crate::agricultural_task::mappers::task_schedule_generation_context_mapper;
use crate::shared::helpers::deep_dup;
use crate::shared::ports::ClockPort;
use crate::shared::type_converters::cast_big_decimal_json;

#[derive(Debug, Clone, thiserror::Error)]
#[error("{0}")]
pub struct TaskScheduleGenerateError(pub String);

pub type WeatherDataMissingError = TaskScheduleGenerateError;
pub type ProgressDataMissingError = TaskScheduleGenerateError;
pub type GddTriggerMissingError = TaskScheduleGenerateError;
pub type TemplateMissingError = TaskScheduleGenerateError;

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

    pub fn generate(
        &self,
        cultivation_plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let ctx = self.build_generation_context(cultivation_plan_id)?;
        let plan = ctx.plan;

        if !weather_data_present(&plan.predicted_weather_data) {
            return Err(Box::new(TaskScheduleGenerateError(format!(
                "CultivationPlan#{} に気象予測データが存在しません",
                plan.id
            ))));
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
        let mut template_rows_by_crop_id = std::collections::HashMap::new();
        let mut blueprint_rows_by_crop_id = std::collections::HashMap::new();
        let mut agrr_requirement_by_crop_id = std::collections::HashMap::new();

        for crop_id in crop_ids {
            crop_rows_by_id.insert(
                crop_id,
                self.task_schedule_read_gateway.find_crop_row(crop_id)?,
            );
            template_rows_by_crop_id.insert(
                crop_id,
                self.task_schedule_read_gateway
                    .list_crop_task_template_rows(crop_id)?,
            );
            blueprint_rows_by_crop_id.insert(
                crop_id,
                self.task_schedule_read_gateway
                    .list_crop_task_schedule_blueprint_rows(crop_id)?,
            );
            agrr_requirement_by_crop_id.insert(
                crop_id,
                self.task_schedule_read_gateway
                    .build_crop_agrr_requirement(crop_id)?,
            );
        }

        Ok(task_schedule_generation_context_mapper::assemble(
            plan_row,
            field_rows,
            crop_rows_by_id,
            template_rows_by_crop_id,
            blueprint_rows_by_crop_id,
            agrr_requirement_by_crop_id,
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
            return Err(Box::new(TaskScheduleGenerateError(format!(
                "Crop#{} ({}) の作業テンプレートが登録されていません",
                crop.id, crop.name
            ))));
        }

        let (general_blueprints, fertilizer_blueprints) = partition_blueprints(blueprints.as_slice());
        if general_blueprints.is_empty() {
            return Err(Box::new(TaskScheduleGenerateError(format!(
                "Crop#{} ({}) の一般作業テンプレートが不足しています",
                crop.id, crop.name
            ))));
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
            return Err(Box::new(TaskScheduleGenerateError(format!(
                "GDD進捗データが空です (cultivation_plan_id={})",
                plan.id
            ))));
        }

        self.create_schedule(plan, field_cultivation, "general", || {
            general_blueprints
                .iter()
                .map(|blueprint| {
                    self.item_attributes_for_blueprint(
                        blueprint,
                        crop,
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
                            crop,
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
        crop: &TaskScheduleCrop,
        progress_records: &[ProgressRecord],
        fallback_start_date: Option<Date>,
    ) -> Result<TaskScheduleReplaceItem, Box<dyn std::error::Error + Send + Sync>> {
        let gdd_trigger = blueprint.gdd_trigger.ok_or_else(|| {
            Box::new(TaskScheduleGenerateError(
                "GDDトリガーが設定されていません".into(),
            )) as Box<dyn std::error::Error + Send + Sync>
        })?;

        let task = find_agricultural_task_for_blueprint(blueprint, crop);
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
            name: name_for_blueprint(blueprint, task.as_ref()),
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

fn find_agricultural_task_for_blueprint(
    blueprint: &TaskScheduleBlueprint,
    _crop: &TaskScheduleCrop,
) -> Option<TaskScheduleRelatedTask> {
    blueprint.agricultural_task.clone()
}

fn name_for_blueprint(
    blueprint: &TaskScheduleBlueprint,
    task: Option<&TaskScheduleRelatedTask>,
) -> String {
    if let Some(task) = task {
        if !task.name.trim().is_empty() {
            return task.name.clone();
        }
    }
    if let Some(ref desc) = blueprint.description {
        if !desc.trim().is_empty() {
            return desc.clone();
        }
    }
    match blueprint.task_type.as_str() {
        BASAL_FERTILIZATION => "基肥施用".into(),
        TOPDRESS_FERTILIZATION => "追肥施用".into(),
        _ => "field_task".into(),
    }
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
                    Box::new(TaskScheduleGenerateError(format!(
                        "GDD {} に対応する日付が見つかりません",
                        target_gdd
                    ))) as Box<dyn std::error::Error + Send + Sync>
                }).or(Ok(fallback_date.unwrap_or_else(|| {
                    Date::from_calendar_date(1970, time::Month::January, 1).expect("valid")
                })));
            }
        }
    }
    if let Some(fallback) = fallback_date {
        return Ok(fallback);
    }
    Err(Box::new(TaskScheduleGenerateError(format!(
        "GDD {} に対応する日付が見つかりません",
        target_gdd
    ))))
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
    let Some(obj) = weather_data.as_object() else {
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::agricultural_task::gateways::TaskSchedulePlanContext;
    use rust_decimal::Decimal;
    use std::str::FromStr;
    use std::sync::Mutex;

    struct FixedClock {
        now: OffsetDateTime,
    }

    impl ClockPort for FixedClock {
        fn today(&self) -> Date {
            self.now.date()
        }

        fn now(&self) -> OffsetDateTime {
            self.now
        }
    }

    struct FakeCultivationPlanGateway;

    impl CultivationPlanGateway for FakeCultivationPlanGateway {
        fn within_transaction<F, T>(&self, block: F) -> T
        where
            F: FnOnce() -> T,
        {
            block()
        }
    }

    struct FakeTaskScheduleReadGateway {
        ctx: TaskSchedulePlanContext,
    }

    impl TaskScheduleGenerationReadGateway for FakeTaskScheduleReadGateway {
        fn find_plan_row(
            &self,
            _: i64,
        ) -> Result<
            crate::agricultural_task::gateways::TaskSchedulePlanRow,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            Ok(crate::agricultural_task::gateways::TaskSchedulePlanRow {
                id: self.ctx.plan.id,
                predicted_weather_data: self.ctx.plan.predicted_weather_data.clone(),
                calculated_planning_start_date: self.ctx.plan.calculated_planning_start_date,
            })
        }

        fn list_field_cultivation_rows(
            &self,
            _: i64,
        ) -> Result<
            Vec<crate::agricultural_task::gateways::TaskScheduleFieldCultivationRow>,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            Ok(self
                .ctx
                .plan
                .field_cultivations
                .iter()
                .map(|fc| crate::agricultural_task::gateways::TaskScheduleFieldCultivationRow {
                    id: fc.id,
                    start_date: fc.start_date,
                    crop_id: fc.crop.as_ref().map(|c| c.id),
                })
                .collect())
        }

        fn find_crop_row(
            &self,
            crop_id: i64,
        ) -> Result<
            crate::agricultural_task::gateways::TaskScheduleCropRow,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            let crop = self
                .ctx
                .plan
                .field_cultivations
                .iter()
                .filter_map(|fc| fc.crop.as_ref())
                .find(|c| c.id == crop_id)
                .ok_or_else(|| "crop not found".to_string())?;
            Ok(crate::agricultural_task::gateways::TaskScheduleCropRow {
                id: crop.id,
                name: crop.name.clone(),
            })
        }

        fn list_crop_task_template_rows(
            &self,
            crop_id: i64,
        ) -> Result<
            Vec<crate::agricultural_task::gateways::TaskScheduleTemplateRow>,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            let crop = self
                .ctx
                .plan
                .field_cultivations
                .iter()
                .filter_map(|fc| fc.crop.as_ref())
                .find(|c| c.id == crop_id)
                .ok_or_else(|| "crop not found".to_string())?;
            Ok(crop
                .crop_task_templates
                .iter()
                .map(|t| crate::agricultural_task::gateways::TaskScheduleTemplateRow {
                    agricultural_task: t.agricultural_task.clone(),
                })
                .collect())
        }

        fn list_crop_task_schedule_blueprint_rows(
            &self,
            crop_id: i64,
        ) -> Result<
            Vec<crate::agricultural_task::gateways::TaskScheduleBlueprintRow>,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            let crop = self
                .ctx
                .plan
                .field_cultivations
                .iter()
                .filter_map(|fc| fc.crop.as_ref())
                .find(|c| c.id == crop_id)
                .ok_or_else(|| "crop not found".to_string())?;
            Ok(crop
                .crop_task_schedule_blueprints
                .iter()
                .enumerate()
                .map(|(index, blueprint)| {
                    crate::agricultural_task::gateways::TaskScheduleBlueprintRow {
                        id: (index + 1) as i64,
                        task_type: blueprint.task_type.clone(),
                        gdd_trigger: blueprint.gdd_trigger,
                        gdd_tolerance: blueprint.gdd_tolerance,
                        description: blueprint.description.clone(),
                        stage_name: blueprint.stage_name.clone(),
                        stage_order: blueprint.stage_order,
                        priority: blueprint.priority,
                        source: blueprint.source.clone(),
                        weather_dependency: blueprint.weather_dependency.clone(),
                        time_per_sqm: blueprint.time_per_sqm,
                        amount: blueprint.amount,
                        amount_unit: blueprint.amount_unit.clone(),
                        agricultural_task: blueprint.agricultural_task.clone(),
                    }
                })
                .collect())
        }

        fn build_crop_agrr_requirement(
            &self,
            _: i64,
        ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            Ok(serde_json::json!({ "crop": { "name": "stub" } }))
        }
    }

    struct CapturingTaskScheduleGateway {
        replaced: Mutex<Vec<ReplaceCall>>,
        cleared: Mutex<Vec<ClearCall>>,
    }

    #[derive(Debug, Clone)]
    struct ReplaceCall {
        cultivation_plan_id: i64,
        field_cultivation_id: i64,
        category: String,
        generated_at: OffsetDateTime,
        items: Vec<TaskScheduleReplaceItem>,
    }

    #[derive(Debug, Clone)]
    struct ClearCall {
        cultivation_plan_id: i64,
        field_cultivation_id: i64,
        category: String,
    }

    impl CapturingTaskScheduleGateway {
        fn new() -> Self {
            Self {
                replaced: Mutex::new(vec![]),
                cleared: Mutex::new(vec![]),
            }
        }
    }

    impl TaskScheduleGateway for CapturingTaskScheduleGateway {
        fn delete_all_for_field_category(
            &self,
            cultivation_plan_id: i64,
            field_cultivation_id: i64,
            category: &str,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            self.cleared.lock().unwrap().push(ClearCall {
                cultivation_plan_id,
                field_cultivation_id,
                category: category.to_string(),
            });
            Ok(())
        }

        fn replace_schedule_for_field_category(
            &self,
            cultivation_plan_id: i64,
            field_cultivation_id: i64,
            category: &str,
            generated_at: OffsetDateTime,
            items: Vec<TaskScheduleReplaceItem>,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            self.replaced.lock().unwrap().push(ReplaceCall {
                cultivation_plan_id,
                field_cultivation_id,
                category: category.to_string(),
                generated_at,
                items,
            });
            Ok(())
        }
    }

    struct StubProgressGateway {
        response: serde_json::Value,
        received: Mutex<Vec<ProgressPayload>>,
    }

    #[derive(Debug, Clone)]
    struct ProgressPayload {
        crop_id: i64,
        start_date: Option<Date>,
        weather_data: serde_json::Value,
    }

    impl ProgressGateway for StubProgressGateway {
        fn calculate_progress(
            &self,
            crop: &TaskScheduleCrop,
            start_date: Option<Date>,
            weather_data: &serde_json::Value,
        ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            self.received.lock().unwrap().push(ProgressPayload {
                crop_id: crop.id,
                start_date,
                weather_data: weather_data.clone(),
            });
            Ok(self.response.clone())
        }
    }

    fn dec(s: &str) -> Decimal {
        Decimal::from_str(s).unwrap()
    }

    fn soil_task() -> TaskScheduleRelatedTask {
        TaskScheduleRelatedTask {
            id: 11,
            name: "土壌準備".into(),
            description: Some("soil".into()),
            weather_dependency: Some("low".into()),
            time_per_sqm: Some(dec("0.1")),
        }
    }

    fn mocked_weather_data() -> serde_json::Value {
        serde_json::json!({
            "location": { "latitude": 35.0, "longitude": 135.0, "timezone": "Asia/Tokyo" },
            "data": [
                { "time": "2025-03-20T00:00:00", "temperature_2m_mean": 10.0 },
                { "time": "2025-03-25T00:00:00", "temperature_2m_mean": 12.0 },
                { "time": "2025-04-01T00:00:00", "temperature_2m_mean": 15.0 },
                { "time": "2025-04-05T00:00:00", "temperature_2m_mean": 18.0 },
                { "time": "2025-04-10T00:00:00", "temperature_2m_mean": 20.0 }
            ]
        })
    }

    fn progress_response() -> serde_json::Value {
        serde_json::json!({
            "progress_records": [
                { "date": "2025-04-01T00:00:00", "cumulative_gdd": 0.0 },
                { "date": "2025-04-04T00:00:00", "cumulative_gdd": 120.0 },
                { "date": "2025-04-06T00:00:00", "cumulative_gdd": 165.0 }
            ],
            "total_gdd": 600.0
        })
    }

    fn build_test_fixtures() -> (
        TaskSchedulePlanContext,
        CapturingTaskScheduleGateway,
        FixedClock,
    ) {
        let general_blueprint = TaskScheduleBlueprint {
            task_type: FIELD_WORK.into(),
            gdd_trigger: Some(dec("0.0")),
            gdd_tolerance: Some(dec("5.0")),
            description: None,
            stage_name: Some("土壌準備".into()),
            stage_order: Some(1),
            priority: Some(1),
            source: Some("agrr_schedule".into()),
            weather_dependency: Some("low".into()),
            time_per_sqm: Some(dec("0.1")),
            amount: None,
            amount_unit: None,
            agricultural_task: Some(soil_task()),
        };
        let basal_blueprint = TaskScheduleBlueprint {
            task_type: BASAL_FERTILIZATION.into(),
            gdd_trigger: Some(dec("0.0")),
            gdd_tolerance: Some(dec("5.0")),
            description: None,
            stage_name: Some("定植前".into()),
            stage_order: Some(0),
            priority: Some(1),
            source: Some("agrr_schedule".into()),
            weather_dependency: None,
            time_per_sqm: None,
            amount: None,
            amount_unit: None,
            agricultural_task: Some(TaskScheduleRelatedTask {
                id: 12,
                name: "基肥".into(),
                description: None,
                weather_dependency: None,
                time_per_sqm: None,
            }),
        };
        let topdress_blueprint = TaskScheduleBlueprint {
            task_type: TOPDRESS_FERTILIZATION.into(),
            gdd_trigger: Some(dec("160.0")),
            gdd_tolerance: Some(dec("10.0")),
            description: None,
            stage_name: Some("生育期".into()),
            stage_order: Some(2),
            priority: Some(2),
            source: Some("agrr_schedule".into()),
            weather_dependency: None,
            time_per_sqm: None,
            amount: Some(dec("4.0")),
            amount_unit: None,
            agricultural_task: Some(TaskScheduleRelatedTask {
                id: 13,
                name: "追肥".into(),
                description: None,
                weather_dependency: None,
                time_per_sqm: None,
            }),
        };

        let crop = TaskScheduleCrop {
            id: 1,
            name: "トマト".into(),
            crop_task_templates: vec![],
            crop_task_schedule_blueprints: vec![
                general_blueprint,
                basal_blueprint,
                topdress_blueprint,
            ],
        };
        let field_cultivation = TaskScheduleFieldCultivation {
            id: 7,
            crop: Some(crop),
            start_date: Date::from_calendar_date(2025, time::Month::April, 1).ok(),
        };
        let plan = TaskSchedulePlan {
            id: 99,
            predicted_weather_data: mocked_weather_data(),
            field_cultivations: vec![field_cultivation],
            calculated_planning_start_date: None,
        };
        let ctx = TaskSchedulePlanContext { plan };
        let task_schedule_gateway = CapturingTaskScheduleGateway::new();
        let clock = FixedClock {
            now: OffsetDateTime::from_unix_timestamp(1_735_689_600).unwrap(),
        };
        (ctx, task_schedule_gateway, clock)
    }

    // Ruby: test "generate! produces general + fertilizer schedules with blueprint-derived items"
    #[test]
    fn generate_produces_general_and_fertilizer_schedules() {
        let (ctx, task_schedule_gateway, clock) = build_test_fixtures();
        let cultivation_plan_gateway = FakeCultivationPlanGateway;
        let task_schedule_read_gateway = FakeTaskScheduleReadGateway { ctx };
        let progress_gateway = StubProgressGateway {
            response: progress_response(),
            received: Mutex::new(vec![]),
        };
        let interactor = TaskScheduleGenerateInteractor::new(
            &progress_gateway,
            &task_schedule_gateway,
            &clock,
            &cultivation_plan_gateway,
            &task_schedule_read_gateway,
        );
        interactor.generate(99).expect("generate");

        let replaced = task_schedule_gateway.replaced.lock().unwrap();
        assert_eq!(replaced.len(), 2);
        let general = replaced.iter().find(|r| r.category == "general").unwrap();
        let fertilizer = replaced.iter().find(|r| r.category == "fertilizer").unwrap();
        assert_eq!(general.items.len(), 1);
        assert_eq!(general.items[0].task_type, FIELD_WORK);
        assert_eq!(general.items[0].agricultural_task_id, Some(11));
        assert_eq!(general.items[0].scheduled_date, Date::from_calendar_date(2025, time::Month::April, 1).unwrap());
        assert_eq!(fertilizer.items.len(), 2);
        assert_eq!(fertilizer.items.last().unwrap().scheduled_date, Date::from_calendar_date(2025, time::Month::April, 6).unwrap());
    }

    // Ruby: test "generate! raises TemplateMissingError when crop has no blueprints"
    #[test]
    fn generate_raises_template_missing_when_no_blueprints() {
        let (mut ctx, task_schedule_gateway, clock) = build_test_fixtures();
        if let Some(fc) = ctx.plan.field_cultivations.first_mut() {
            if let Some(crop) = fc.crop.as_mut() {
                crop.crop_task_schedule_blueprints.clear();
            }
        }
        let cultivation_plan_gateway = FakeCultivationPlanGateway;
        let task_schedule_read_gateway = FakeTaskScheduleReadGateway { ctx };
        let progress_gateway = StubProgressGateway {
            response: progress_response(),
            received: Mutex::new(vec![]),
        };
        let interactor = TaskScheduleGenerateInteractor::new(
            &progress_gateway,
            &task_schedule_gateway,
            &clock,
            &cultivation_plan_gateway,
            &task_schedule_read_gateway,
        );
        let err = interactor.generate(99).unwrap_err();
        assert!(err.to_string().contains("作業テンプレートが登録されていません"));
    }

    // Ruby: test "generate! raises ProgressDataMissingError when progress has no records"
    #[test]
    fn generate_raises_progress_missing_when_no_records() {
        let (ctx, task_schedule_gateway, clock) = build_test_fixtures();
        let cultivation_plan_gateway = FakeCultivationPlanGateway;
        let task_schedule_read_gateway = FakeTaskScheduleReadGateway { ctx };
        let progress_gateway = StubProgressGateway {
            response: serde_json::json!({ "progress_records": [] }),
            received: Mutex::new(vec![]),
        };
        let interactor = TaskScheduleGenerateInteractor::new(
            &progress_gateway,
            &task_schedule_gateway,
            &clock,
            &cultivation_plan_gateway,
            &task_schedule_read_gateway,
        );
        let err = interactor.generate(99).unwrap_err();
        assert!(err.to_string().contains("GDD進捗データが空です"));
    }

    // Ruby: test "progress gateway receives weather data filtered from the start date"
    #[test]
    fn progress_gateway_receives_filtered_weather() {
        let (ctx, task_schedule_gateway, clock) = build_test_fixtures();
        let cultivation_plan_gateway = FakeCultivationPlanGateway;
        let task_schedule_read_gateway = FakeTaskScheduleReadGateway { ctx };
        let progress_gateway = StubProgressGateway {
            response: progress_response(),
            received: Mutex::new(vec![]),
        };
        let interactor = TaskScheduleGenerateInteractor::new(
            &progress_gateway,
            &task_schedule_gateway,
            &clock,
            &cultivation_plan_gateway,
            &task_schedule_read_gateway,
        );
        interactor.generate(99).expect("generate");
        let payload = progress_gateway.received.lock().unwrap().last().unwrap().clone();
        let times: Vec<_> = payload
            .weather_data
            .get("data")
            .and_then(|v| v.as_array())
            .unwrap()
            .iter()
            .filter_map(|e| e.get("time").and_then(|t| t.as_str()))
            .collect();
        assert!(!times.is_empty());
        let start = Date::from_calendar_date(2025, time::Month::April, 1).unwrap();
        assert!(times.iter().all(|t| safe_parse_date(t).unwrap() >= start));
    }

    // Ruby: test "generate! raises GddTriggerMissingError when a blueprint has no gdd trigger"
    #[test]
    fn generate_raises_gdd_trigger_missing() {
        let (mut ctx, task_schedule_gateway, clock) = build_test_fixtures();
        if let Some(fc) = ctx.plan.field_cultivations.first_mut() {
            if let Some(crop) = fc.crop.as_mut() {
                crop.crop_task_schedule_blueprints[0].gdd_trigger = None;
            }
        }
        let cultivation_plan_gateway = FakeCultivationPlanGateway;
        let task_schedule_read_gateway = FakeTaskScheduleReadGateway { ctx };
        let progress_gateway = StubProgressGateway {
            response: progress_response(),
            received: Mutex::new(vec![]),
        };
        let interactor = TaskScheduleGenerateInteractor::new(
            &progress_gateway,
            &task_schedule_gateway,
            &clock,
            &cultivation_plan_gateway,
            &task_schedule_read_gateway,
        );
        let err = interactor.generate(99).unwrap_err();
        assert!(err.to_string().contains("GDDトリガーが設定されていません"));
    }
}
