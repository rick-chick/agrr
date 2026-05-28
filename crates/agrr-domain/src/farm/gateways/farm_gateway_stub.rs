//! Test stub for [`FarmGateway`] — all methods `unimplemented!()` unless overridden in tests.

use crate::farm::dtos::{FarmDeleteUsage, FarmDetailOutput};
use crate::farm::entities::FarmEntity;
use crate::farm::gateways::{FarmGateway, SoftDeleteWithUndoOutcome};
use crate::shared::attr::AttrMap;
use crate::shared::user::User;

pub struct FarmGatewayStub;

impl FarmGateway for FarmGatewayStub {
    fn list_user_owned_farms(
        &self,
        _: i64,
    ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn list_user_and_reference_farms(
        &self,
        _: i64,
    ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn list_reference_farms(
        &self,
    ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_by_id(
        &self,
        _: i64,
    ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn update_weather_progress(
        &self,
        _: i64,
        _: AttrMap,
    ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn list_reference_farms_for_region(
        &self,
        _: &str,
    ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn count_user_owned_non_reference_farms(
        &self,
        _: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn create_for_user(
        &self,
        _: &User,
        _: AttrMap,
    ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn update_for_user(
        &self,
        _: &User,
        _: i64,
        _: AttrMap,
    ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn farm_detail_with_fields(
        &self,
        _: i64,
    ) -> Result<FarmDetailOutput, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_delete_usage(
        &self,
        _: i64,
    ) -> Result<FarmDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn soft_delete_with_undo(
        &self,
        _: &User,
        _: i64,
        _: i64,
        _: &str,
    ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
}
