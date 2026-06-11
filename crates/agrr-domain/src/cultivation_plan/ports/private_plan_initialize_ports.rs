//! Ports for `PrivatePlanInitializeFromSelectionInteractor`.

use time::Date;

use crate::cultivation_plan::dtos::{
    CultivationPlanInitFarm, CultivationPlanInitializeResult, PrivatePlanMasterFieldSeed,
};
use crate::cultivation_plan::entities::CultivationPlanEntity;
use crate::farm::entities::FarmEntity;

pub trait PrivatePlanExistingPlanGateway: Send + Sync {
    fn find_existing(
        &self,
        farm_id: i64,
        user_id: i64,
    ) -> Result<Option<CultivationPlanEntity>, Box<dyn std::error::Error + Send + Sync>>;
}

pub trait PrivatePlanCropListGateway: Send + Sync {
    fn list_by_ids(
        &self,
        crop_ids: &[i64],
    ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>>;
}

pub trait PrivatePlanInitializeCallablePort: Send + Sync {
    fn call(
        &self,
        farm: &CultivationPlanInitFarm,
        master_fields: &[PrivatePlanMasterFieldSeed],
        user_id: i64,
        session_id: &str,
        plan_name: &str,
        planning_start_date: Date,
        planning_end_date: Date,
    ) -> Result<CultivationPlanInitializeResult, Box<dyn std::error::Error + Send + Sync>>;
}

pub trait PrivatePlanSessionIdGeneratorPort: Send + Sync {
    fn generate(&self) -> String;
}

pub trait PrivatePlanOptimizationJobChainGateway: Send + Sync {
    fn enqueue_after_create(
        &self,
        cultivation_plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}

/// Resolves owned farm for private plan initialization.
pub trait PrivatePlanFarmResolveGateway: Send + Sync {
    fn find_by_id(
        &self,
        farm_id: i64,
    ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>>;
}
