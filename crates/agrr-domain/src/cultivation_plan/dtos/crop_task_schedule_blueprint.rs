//! Blueprint copy DTOs.

use rust_decimal::Decimal;

#[derive(Debug, Clone, PartialEq)]
pub struct CropTaskScheduleBlueprintCopyInput {
    pub reference_crop_id_to_user_crop_id: Vec<(i64, i64)>,
}

impl CropTaskScheduleBlueprintCopyInput {
    pub fn from_map(map: impl IntoIterator<Item = (i64, i64)>) -> Self {
        Self {
            reference_crop_id_to_user_crop_id: map.into_iter().collect(),
        }
    }

    pub fn is_empty(&self) -> bool {
        self.reference_crop_id_to_user_crop_id.is_empty()
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct CropTaskScheduleBlueprintRow {
    pub agricultural_task_id: Option<i64>,
    pub source_agricultural_task_id: Option<i64>,
    pub stage_order: i32,
    pub stage_name: String,
    pub gdd_trigger: Option<Decimal>,
    pub gdd_tolerance: Option<Decimal>,
    pub task_type: String,
    pub source: String,
    pub priority: i32,
    pub amount: Option<Decimal>,
    pub amount_unit: Option<String>,
    pub description: Option<String>,
    pub weather_dependency: Option<String>,
    pub time_per_sqm: Option<Decimal>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CropTaskScheduleBlueprintCreateAttrs {
    pub crop_id: i64,
    pub agricultural_task_id: Option<i64>,
    pub source_agricultural_task_id: Option<i64>,
    pub stage_order: i32,
    pub stage_name: String,
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
}
