#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CropSetupProposalValidationError {
    pub path: String,
    pub message: String,
}

impl CropSetupProposalValidationError {
    pub fn new(path: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            path: path.into(),
            message: message.into(),
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct CropSetupProposalStagePlan {
    pub name: String,
    pub order: i32,
    pub temperature_requirement: Option<serde_json::Value>,
    pub thermal_requirement: serde_json::Value,
    pub sunshine_requirement: Option<serde_json::Value>,
    pub nutrient_requirement: Option<serde_json::Value>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CropSetupProposalAgriculturalTaskPlan {
    pub ref_key: String,
    pub name: String,
    pub description: Option<String>,
    pub time_per_sqm: Option<f64>,
    pub skill_level: Option<String>,
    pub region: String,
    pub task_type: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CropSetupProposalBlueprintPlan {
    pub agricultural_task_ref: String,
    pub stage_order: i32,
    pub stage_name: Option<String>,
    pub gdd_trigger: f64,
    pub task_type: String,
    pub priority: i32,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CropSetupProposalPlan {
    pub stages: Vec<CropSetupProposalStagePlan>,
    pub agricultural_tasks: Vec<CropSetupProposalAgriculturalTaskPlan>,
    pub task_schedule_blueprints: Vec<CropSetupProposalBlueprintPlan>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CropSetupProposalApplyResult {
    pub stage_ids: Vec<i64>,
    pub agricultural_task_ids: Vec<i64>,
    pub blueprint_ids: Vec<i64>,
}
