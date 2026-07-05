//! Attributes for bulk insert during blueprint regeneration.
#[derive(Debug, Clone, PartialEq)]
pub struct CropTaskScheduleBlueprintPersistAttrs {
    pub crop_id: i64,
    pub agricultural_task_id: Option<i64>,
    pub source_agricultural_task_id: Option<i64>,
    pub stage_order: Option<i32>,
    pub stage_name: Option<String>,
    pub gdd_trigger: Option<String>,
    pub gdd_tolerance: Option<String>,
    pub task_type: String,
    pub source: String,
    pub priority: i32,
    pub amount: Option<String>,
    pub amount_unit: Option<String>,
    pub description: Option<String>,
    pub weather_dependency: Option<String>,
    pub time_per_sqm: Option<String>,
    pub name: Option<String>,
}

impl From<crate::crop::task_schedule_blueprint_from_agrr::TaskScheduleBlueprintRow>
    for CropTaskScheduleBlueprintPersistAttrs
{
    fn from(row: crate::crop::task_schedule_blueprint_from_agrr::TaskScheduleBlueprintRow) -> Self {
        use rust_decimal::Decimal;
        fn dec_str_opt(d: Option<Decimal>) -> Option<String> {
            d.map(|v| v.to_string())
        }
        Self {
            crop_id: row.crop_id,
            agricultural_task_id: Some(row.agricultural_task_id),
            source_agricultural_task_id: None,
            stage_order: row.stage_order.map(|v| v as i32),
            stage_name: row.stage_name,
            gdd_trigger: dec_str_opt(row.gdd_trigger),
            gdd_tolerance: dec_str_opt(row.gdd_tolerance),
            task_type: row.task_type,
            source: row.source,
            priority: row.priority.unwrap_or(0) as i32,
            amount: dec_str_opt(row.amount),
            amount_unit: row.amount_unit,
            description: row.description,
            weather_dependency: row.weather_dependency,
            time_per_sqm: dec_str_opt(row.time_per_sqm),
            name: row.name.clone(),
        }
    }
}
