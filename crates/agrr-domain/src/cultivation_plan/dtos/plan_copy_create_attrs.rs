//! Ruby: `Domain::CultivationPlan::Dtos::PlanCopyInput`, `PlanCopyCreateAttrs`, copy row types.

use time::Date;

#[derive(Debug, Clone, PartialEq)]
pub struct PlanCopyInput {
    pub source_cultivation_plan_id: i64,
    pub user_id: i64,
    pub new_year: i32,
    pub session_id: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlanCopyCreateAttrs {
    pub farm_id: i64,
    pub user_id: i64,
    pub total_area: f64,
    pub plan_type: String,
    pub plan_year: i32,
    pub plan_name: Option<String>,
    pub planning_start_date: Date,
    pub planning_end_date: Date,
    pub status: String,
    pub session_id: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlanCopySourcePlan {
    pub id: i64,
    pub farm_id: i64,
    pub total_area: f64,
    pub plan_name: Option<String>,
}

pub type PlanCopyFieldSnapshot = super::plan_copy_field_row::PlanCopyFieldRow;
pub type PlanCopyCropSnapshot = super::plan_copy_crop_row::PlanCopyCropRow;
pub type PlanCopyFieldCultivationSnapshot = super::plan_copy_field_cultivation_row::PlanCopyFieldCultivationRow;
