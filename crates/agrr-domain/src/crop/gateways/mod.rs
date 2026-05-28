mod crop_gateway;
mod crop_masters_task_template_gateway;
mod crop_stage_gateway;
mod nutrient_requirement_gateway;
mod sunshine_requirement_gateway;
mod temperature_requirement_gateway;
mod thermal_requirement_gateway;

#[cfg(test)]
pub mod crop_gateway_stub;

pub use crop_gateway::{
    CropGateway, SoftDeleteWithUndoOutcome, UpdateMastersCropTaskTemplateOutcome,
};
pub use crop_masters_task_template_gateway::CropMastersTaskTemplateGateway;
pub use crop_stage_gateway::CropStageGateway;
pub use nutrient_requirement_gateway::NutrientRequirementGateway;
pub use sunshine_requirement_gateway::SunshineRequirementGateway;
pub use temperature_requirement_gateway::TemperatureRequirementGateway;
pub use thermal_requirement_gateway::ThermalRequirementGateway;
