//! `CropMastersTaskScheduleBlueprintGateway` — masters crop task schedule blueprint CRUD.

use crate::crop::crop_task_schedule_blueprint_sqlite::{
    delete_blueprint_by_id, delete_fertilize_blueprints_for_crop, insert_blueprint,
    list_blueprints_by_crop_id, replace_all_blueprints_for_crop, update_blueprint,
    update_regenerated_field_work,
};
use crate::pool::SqlitePool;
use agrr_domain::crop::dtos::{
    CropTaskScheduleBlueprintPersistAttrs, MastersCropTaskScheduleBlueprint,
};
use agrr_domain::crop::gateways::CropMastersTaskScheduleBlueprintGateway;
use serde_json::Value;

pub struct CropMastersTaskScheduleBlueprintSqliteGateway {
    pool: SqlitePool,
}

impl CropMastersTaskScheduleBlueprintSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl CropMastersTaskScheduleBlueprintGateway for CropMastersTaskScheduleBlueprintSqliteGateway {
    fn list_by_crop_id(
        &self,
        crop_id: i64,
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>>
    {
        list_blueprints_by_crop_id(&self.pool, crop_id)
    }

    fn create(
        &self,
        attrs: CropTaskScheduleBlueprintPersistAttrs,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
        insert_blueprint(&self.pool, &attrs)
    }

    fn update(
        &self,
        crop_id: i64,
        blueprint_id: i64,
        attributes: Value,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
        update_blueprint(&self.pool, crop_id, blueprint_id, attributes)
    }

    fn delete_by_id(
        &self,
        crop_id: i64,
        blueprint_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        delete_blueprint_by_id(&self.pool, crop_id, blueprint_id)
    }

    fn replace_all_for_crop(
        &self,
        crop_id: i64,
        records: &[CropTaskScheduleBlueprintPersistAttrs],
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, Box<dyn std::error::Error + Send + Sync>>
    {
        replace_all_blueprints_for_crop(&self.pool, crop_id, records)
    }

    fn delete_fertilize_blueprints_for_crop(
        &self,
        crop_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        delete_fertilize_blueprints_for_crop(&self.pool, crop_id)
    }

    fn update_regenerated_field_work(
        &self,
        crop_id: i64,
        blueprint_id: i64,
        attrs: &CropTaskScheduleBlueprintPersistAttrs,
    ) -> Result<MastersCropTaskScheduleBlueprint, Box<dyn std::error::Error + Send + Sync>> {
        update_regenerated_field_work(&self.pool, crop_id, blueprint_id, attrs)
    }
}
