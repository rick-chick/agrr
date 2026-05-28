//! Private plan list / detail DTOs.

use serde_json::Value;
use time::Date;

#[derive(Debug, Clone, PartialEq)]
pub struct PrivatePlanIndexPlanRow {
    pub id: i64,
    pub farm_display_name: String,
    pub total_area: f64,
    pub crops_count: i32,
    pub fields_count: i32,
    pub status: String,
    pub display_name: String,
    pub created_at: String,
}

impl PrivatePlanIndexPlanRow {
    pub fn completed(&self) -> bool {
        self.status == "completed"
    }

    pub fn optimizing(&self) -> bool {
        self.status == "optimizing"
    }

    pub fn pending(&self) -> bool {
        self.status == "pending"
    }

    pub fn failed(&self) -> bool {
        self.status == "failed"
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct PrivatePlanReadSnapshot {
    pub id: i64,
    pub display_name: String,
    pub farm_display_name: String,
    pub total_area: f64,
    pub field_cultivations_count: i32,
    pub cultivation_plan_fields_count: i32,
    pub planning_start_date: Option<Date>,
    pub planning_end_date: Option<Date>,
    pub status: String,
    pub field_cultivations: Vec<Value>,
    pub cultivation_plan_fields: Vec<Value>,
    pub palette_used_crop_ids: Vec<i64>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PrivatePlanShowPaletteCrop {
    pub id: i64,
    pub name: String,
    pub variety: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PrivateCultivationPlanDetail {
    pub id: i64,
    pub display_name: String,
    pub farm_display_name: String,
    pub total_area: f64,
    pub field_cultivations_count: i32,
    pub cultivation_plan_fields_count: i32,
    pub planning_start_date: Option<Date>,
    pub planning_end_date: Option<Date>,
    pub status: String,
    pub field_cultivations: Vec<Value>,
    pub cultivation_plan_fields: Vec<Value>,
    pub palette_used_crop_ids: Vec<i64>,
    pub palette_crops: Vec<PrivatePlanShowPaletteCrop>,
}
