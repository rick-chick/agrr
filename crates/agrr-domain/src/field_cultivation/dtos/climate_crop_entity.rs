use serde_json::Value;

#[derive(Debug, Clone, PartialEq)]
pub struct ClimateTemperatureRequirement {
    pub base_temperature: f64,
    pub optimal_min: Option<f64>,
    pub optimal_max: Option<f64>,
    pub low_stress_threshold: Option<f64>,
    pub high_stress_threshold: Option<f64>,
    pub frost_threshold: Option<f64>,
    pub max_temperature: Option<f64>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ClimateThermalRequirement {
    pub required_gdd: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ClimateCropStage {
    pub name: String,
    pub order: i32,
    pub temperature_requirement: Option<ClimateTemperatureRequirement>,
    pub thermal_requirement: Option<ClimateThermalRequirement>,
}

/// Crop view for climate UC (agrr `progress` crop-file shape matches `CropAgrrRequirementMapper`).
#[derive(Debug, Clone, PartialEq)]
pub struct ClimateCropEntity {
    pub id: i64,
    pub name: String,
    pub variety: Option<String>,
    pub area_per_unit: Option<f64>,
    pub revenue_per_area: Option<f64>,
    pub groups: Value,
    pub is_reference: bool,
    pub user_id: Option<i64>,
    pub crop_stages: Vec<ClimateCropStage>,
}
