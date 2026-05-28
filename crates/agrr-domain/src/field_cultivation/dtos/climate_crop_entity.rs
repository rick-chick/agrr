use serde_json::Value;

#[derive(Debug, Clone, PartialEq)]
pub struct ClimateTemperatureRequirement {
    pub base_temperature: f64,
    pub optimal_min: Option<f64>,
    pub optimal_max: Option<f64>,
    pub low_stress_threshold: Option<f64>,
    pub high_stress_threshold: Option<f64>,
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

/// Minimal crop view for climate UC (avoids `crop` module dependency).
#[derive(Debug, Clone, PartialEq)]
pub struct ClimateCropEntity {
    pub id: i64,
    pub is_reference: bool,
    pub user_id: Option<i64>,
    pub crop_stages: Vec<ClimateCropStage>,
}

impl ClimateCropEntity {
    pub fn stages_for_mapper(&self) -> Vec<Value> {
        self.crop_stages
            .iter()
            .filter_map(|st| {
                let temp = st.temperature_requirement.as_ref()?;
                let thermal = st.thermal_requirement.as_ref()?;
                Some(serde_json::json!({
                    "name": st.name,
                    "order": st.order,
                    "gdd_required": thermal.required_gdd,
                    "optimal_temperature_min": temp.optimal_min,
                    "optimal_temperature_max": temp.optimal_max,
                    "low_stress_threshold": temp.low_stress_threshold,
                    "high_stress_threshold": temp.high_stress_threshold,
                }))
            })
            .collect()
    }
}
