pub mod agrr_requirement;
mod crop_agrr_requirement_gateway;
mod crop_ai_upsert_sqlite_persistence;
mod crop_gateway;
mod crop_masters_task_schedule_blueprint_gateway;
mod crop_task_schedule_blueprint_sqlite;
mod source_crop_lookup_gateway;
mod crop_stage_gateway;
mod requirement_gateways;

#[cfg(test)]
mod crop_gateway_test;

pub use crop_ai_upsert_sqlite_persistence::CropAiUpsertSqlitePersistence;
pub use crop_agrr_requirement_gateway::CropAgrrRequirementSqliteGateway;
pub use crop_gateway::CropSqliteGateway;
pub use crop_masters_task_schedule_blueprint_gateway::CropMastersTaskScheduleBlueprintSqliteGateway;
pub use source_crop_lookup_gateway::CropSourceCropLookupSqliteGateway;
pub use crop_stage_gateway::CropStageSqliteGateway;
pub use requirement_gateways::{
    NutrientRequirementSqliteGateway, SunshineRequirementSqliteGateway,
    TemperatureRequirementSqliteGateway, ThermalRequirementSqliteGateway,
};
