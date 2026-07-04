//! SQLite adapters for `agrr-domain` gateway traits.
//!
//! Implementations follow the Ruby P4 pattern: **JOIN preload + row mapping into domain DTOs** —
//! no thick snapshot assembly in the adapter (ARCHITECTURE.md Gateway boundary).
//!
//! **P6 status**: reference implementation only — not wired to production URL map until R4 contract GREEN.

pub mod api_keys;
pub mod backdoor;
pub mod auth;
pub mod contact_messages;
pub mod crop;
pub mod cultivation_plan;
pub mod deletion_undo;
pub mod farm;
pub mod fertilize;
pub mod pesticide;
pub mod interaction_rule;
pub mod internal_jobs;
pub mod agricultural_task;
pub mod field;
pub mod field_cultivation;
pub mod pest;
pub mod pool;
pub mod public_plan;
pub mod shared;
pub mod soft_delete;
pub mod weather_data;
pub mod work_record;

pub use api_keys::UserApiKeyRotationSqliteGateway;
pub use backdoor::{
    ApplicationDatabaseClearSqliteGateway, BackdoorCreateUserAttrs, BackdoorCreateUserResult,
    BackdoorDbStatsCounts, BackdoorDiagnosticsSqliteGateway, BackdoorUpdateUserAttrs,
    BackdoorUpdateUserResult, BackdoorUserDetail, BackdoorUserSummary, BackdoorUsersListPayload,
    ShellStdoutCaptureCliGateway,
};
pub use auth::{
    AuthOmniauthSessionSqliteGateway, AuthTestLoginSqliteGateway, GoogleOAuthUserInfo,
    OmniauthCallbackResult, OmniauthCallbackStatus, SessionLookupSqliteGateway, SessionRecord,
    UserSessionRevocationSqliteGateway,
};
pub use contact_messages::ContactMessageSqliteGateway;
pub use crop::{
    CropAiUpsertSqlitePersistence, CropAgrrRequirementSqliteGateway,
    CropMastersTaskScheduleBlueprintSqliteGateway, CropMastersTaskTemplateSqliteGateway,
    CropSqliteGateway,
    CropSourceCropLookupSqliteGateway, CropStageSqliteGateway,
    NutrientRequirementSqliteGateway,
    SunshineRequirementSqliteGateway, TemperatureRequirementSqliteGateway,
    ThermalRequirementSqliteGateway,
};
pub use deletion_undo::DeletionUndoSqliteGateway;
pub use fertilize::FertilizeSqliteGateway;
pub use pesticide::{PesticideCropSqliteGateway, PesticideSqliteGateway};
pub use interaction_rule::{InteractionRulePlanReadSqliteGateway, InteractionRuleSqliteGateway};
pub use agricultural_task::{
    AgTaskCropSqliteGateway, AgriculturalTaskSqliteGateway, CropTaskTemplateSqliteGateway,
};
pub use pest::{CropPestSqliteGateway, PestCropSqliteGateway, PestSqliteGateway};
pub use cultivation_plan::{
    CultivationPlanFieldMutationSqliteGateway, CultivationPlanPlanCropSqliteGateway,
    CultivationPlanPrivateReadSqliteGateway, CultivationPlanPrivateSnapshotReadSqliteGateway,
    CropRowsAvailablePrivateSqliteGateway, CultivationPlanRestPlanReadDomainSqliteGateway,
    CultivationPlanOptimizationSqliteGateway, CultivationPlanRestPlanReadSqliteGateway,
    CultivationPlanSqliteGateway, OptimizationPlanReadSqliteGateway,
    PlanAllocationAdjustDebugDumpFileGateway, PlanAllocationAdjustReadSqliteGateway,
    PublicPlanSavePersistenceSqliteAdapter, PublicPlanSaveReadSqliteGateway,
    TaskScheduleGenerationReadSqliteGateway, TaskScheduleGenerationTransactionSqliteGateway,
    TaskScheduleItemMutationSqliteGateway, TaskScheduleSqliteGateway,
    TaskScheduleSyncStateSqliteGateway,
};
pub use farm::FarmSqliteGateway;
pub use internal_jobs::SchedulerWeatherFarmListSqliteGateway;
pub use field::FieldSqliteGateway;
pub use public_plan::{
    CropRowsAvailablePublicSqliteGateway, PublicPlanCropSqliteGateway, PublicPlanSqliteGateway,
};
pub use shared::{
    find_farm as internal_api_find_farm, ApiKeyPrincipalSqliteGateway,
    InternalApiFarmLookupResult, InternalApiFarmRow, SessionCookiePrincipalSqliteGateway,
    SessionUserReadSqliteGateway, SessionUserRow, UserLookupSqliteGateway,
};
pub use field_cultivation::{
    FieldCultivationClimateSourceSqliteGateway, FieldCultivationCropSqliteGateway,
    FieldCultivationPlanPredictedWeatherSqliteGateway, FieldCultivationSyncPlanReadSqliteGateway,
    FieldCultivationSyncSqliteGateway, FieldCultivationWeatherDataFromStorageGateway,
};
pub use pool::SqlitePool;
pub use weather_data::{
    validate_weather_storage_config, InternalFarmWeatherReadSqliteGateway,
    InternalWeatherFetchStartSqliteGateway, PredictedWeatherGatewayBundle,
    PredictedWeatherMetadataSqliteGateway, WeatherDataFarmSqliteGateway,
    WeatherDataGatewayBundle, WeatherDataSqliteGateway,
};
pub use work_record::{TaskScheduleItemLookupSqliteGateway, WorkHubReadSqliteGateway, WorkRecordSqliteGateway};
