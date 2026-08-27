//! SQLite adapter for private plan create readiness checks.

use agrr_domain::crop::gateways::CropGateway;
use agrr_domain::cultivation_plan::gateways::CropTaskScheduleBlueprintGateway;
use agrr_domain::cultivation_plan::policies::plan_create_readiness_policy;
use agrr_domain::cultivation_plan::ports::PrivatePlanCreateReadinessGateway;
use agrr_domain::shared::policies::crop_policy;
use agrr_domain::shared::user::User;

use crate::crop::CropSqliteGateway;
use crate::cultivation_plan::plan_save_gateways::CropTaskScheduleBlueprintGw;
use crate::pool::SqlitePool;
use crate::shared::UserOrganizationScopeSqliteGateway;

pub struct PrivatePlanCreateReadinessSqliteGateway {
    pool: SqlitePool,
}

impl PrivatePlanCreateReadinessSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl PrivatePlanCreateReadinessGateway for PrivatePlanCreateReadinessSqliteGateway {
    fn user_has_ready_crop(
        &self,
        user: &User,
    ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
        let crop_gateway = CropSqliteGateway::new(self.pool.clone());
        let blueprint_gateway = CropTaskScheduleBlueprintGw::new(self.pool.clone());
        let scope_gateway = UserOrganizationScopeSqliteGateway::new(self.pool.clone());

        let filter = crop_policy::index_list_filter_for_user(&scope_gateway, user)?;
        let crops = crop_gateway
            .list_index_for_filter(&filter)?
            .into_iter()
            .filter(|crop| !crop.is_reference)
            .collect::<Vec<_>>();

        let mut crop_inputs = Vec::with_capacity(crops.len());
        for crop in crops {
            let stages = crop_gateway.list_by_crop_id(crop.id)?;
            let blueprints = blueprint_gateway.list_by_crop_id(crop.id)?;
            crop_inputs.push((stages, blueprints));
        }

        Ok(plan_create_readiness_policy::crops_ready(&crop_inputs))
    }
}
