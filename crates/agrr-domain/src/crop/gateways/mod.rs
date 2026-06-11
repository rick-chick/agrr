pub(crate) mod crop_gateway;
pub(crate) mod crop_source_crop_lookup_gateway;
pub(crate) mod crop_masters_task_template_gateway;
pub(crate) mod crop_stage_gateway;
pub(crate) mod nutrient_requirement_gateway;
pub(crate) mod sunshine_requirement_gateway;
pub(crate) mod temperature_requirement_gateway;
pub(crate) mod thermal_requirement_gateway;

#[cfg(test)]
pub mod crop_gateway_stub;

pub use crop_gateway::{
    CropGateway, SoftDeleteWithUndoOutcome, UpdateMastersCropTaskTemplateOutcome,
};
pub use crop_source_crop_lookup_gateway::CropSourceCropLookupGateway;
pub use crop_masters_task_template_gateway::CropMastersTaskTemplateGateway;
pub use crop_stage_gateway::CropStageGateway;
pub use nutrient_requirement_gateway::NutrientRequirementGateway;
pub use sunshine_requirement_gateway::SunshineRequirementGateway;
pub use temperature_requirement_gateway::TemperatureRequirementGateway;
pub use thermal_requirement_gateway::ThermalRequirementGateway;
