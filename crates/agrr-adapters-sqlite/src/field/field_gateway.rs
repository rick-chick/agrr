//! Ruby: `FieldActiveRecordGateway` — masters fields (P6).

use crate::deletion_undo::schedule_destroy;
use crate::farm::farm_gateway::FarmSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::farm::gateways::FarmGateway;
use agrr_domain::field::dtos::{FieldCreateInput, FieldUpdateInput};
use agrr_domain::field::entities::FieldEntity;
use agrr_domain::field::gateways::FieldGateway;
use agrr_domain::field::results::{FarmFieldsList, FarmRecord, FieldWithFarm};
use agrr_domain::farm::entities::FarmEntity;
use agrr_domain::shared::exceptions::AssociationInUseError;
use agrr_domain::shared::policies::farm_policy::FarmRecordAccessPolicy;
use agrr_domain::shared::reference_record_access_filter::ReferenceRecordAccessFilter;
use rusqlite::params;
use serde_json::json;
use std::collections::BTreeMap;

pub struct FieldSqliteGateway {
    pool: SqlitePool,
}

impl FieldSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl FieldGateway for FieldSqliteGateway {
    fn get_total_area_by_farm_id(
        &self,
        farm_id: i64,
    ) -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let total: f64 = conn.query_row(
                "SELECT COALESCE(SUM(area), 0) FROM fields WHERE farm_id = ?1",
                params![farm_id],
                |row| row.get(0),
            )?;
            Ok(total)
        })
    }

    fn farm_fields_list(
        &self,
        farm_id: i64,
    ) -> Result<FarmFieldsList, Box<dyn std::error::Error + Send + Sync>> {
        let farm_gw = FarmSqliteGateway::new(self.pool.clone());
        let farm = FarmGateway::find_by_id(&farm_gw, farm_id)?;
        let fields = self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, name, area, daily_fixed_cost, region, farm_id, user_id, created_at, updated_at \
                 FROM fields WHERE farm_id = ?1 ORDER BY name",
            )?;
            let rows = stmt.query_map(params![farm_id], map_field_row)?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })?;
        Ok(FarmFieldsList {
            farm: farm_entity_to_record(farm),
            fields,
        })
    }

    fn field_with_farm(
        &self,
        field_id: i64,
    ) -> Result<FieldWithFarm, Box<dyn std::error::Error + Send + Sync>> {
        let field = self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, name, area, daily_fixed_cost, region, farm_id, user_id, created_at, updated_at \
                 FROM fields WHERE id = ?1 LIMIT 1",
            )?;
            stmt.query_row(params![field_id], map_field_row)
        })?;
        let farm_gw = FarmSqliteGateway::new(self.pool.clone());
        let farm = FarmGateway::find_by_id(&farm_gw, field.farm_id)?;
        Ok(FieldWithFarm {
            farm: farm_entity_to_record(farm),
            field,
        })
    }

    fn create(
        &self,
        create_input: &FieldCreateInput,
        farm_id: i64,
        farm_access_filter: &ReferenceRecordAccessFilter<FarmRecordAccessPolicy>,
    ) -> Result<FieldEntity, Box<dyn std::error::Error + Send + Sync>> {
        let farm_gw = FarmSqliteGateway::new(self.pool.clone());
        let farm = FarmGateway::find_by_id(&farm_gw, farm_id)?;
        let user_id = farm_access_filter.user().id;
        let region = create_input
            .region
            .clone()
            .or(farm.region.clone());
        let new_id = self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO fields (farm_id, user_id, name, area, daily_fixed_cost, region, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, datetime('now'), datetime('now'))",
                params![
                    farm_id,
                    user_id,
                    create_input.name,
                    create_input.area,
                    create_input.daily_fixed_cost,
                    region,
                ],
            )?;
            Ok(conn.last_insert_rowid())
        })?;
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, name, area, daily_fixed_cost, region, farm_id, user_id, created_at, updated_at \
                 FROM fields WHERE id = ?1",
            )?;
            stmt.query_row(params![new_id], map_field_row)
        })
    }

    fn update(
        &self,
        field_id: i64,
        update_input: &FieldUpdateInput,
    ) -> Result<FieldEntity, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            if let Some(name) = &update_input.name {
                conn.execute(
                    "UPDATE fields SET name = ?1, updated_at = datetime('now') WHERE id = ?2",
                    params![name, field_id],
                )?;
            }
            if let Some(area) = update_input.area {
                conn.execute(
                    "UPDATE fields SET area = ?1, updated_at = datetime('now') WHERE id = ?2",
                    params![area, field_id],
                )?;
            }
            if let Some(cost) = update_input.daily_fixed_cost {
                conn.execute(
                    "UPDATE fields SET daily_fixed_cost = ?1, updated_at = datetime('now') WHERE id = ?2",
                    params![cost, field_id],
                )?;
            }
            if let Some(region) = &update_input.region {
                conn.execute(
                    "UPDATE fields SET region = ?1, updated_at = datetime('now') WHERE id = ?2",
                    params![region, field_id],
                )?;
            }
            Ok(())
        })?;
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, name, area, daily_fixed_cost, region, farm_id, user_id, created_at, updated_at \
                 FROM fields WHERE id = ?1",
            )?;
            stmt.query_row(params![field_id], map_field_row)
        })
    }

    fn delete(
        &self,
        field_id: i64,
    ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
        let with_farm = self.field_with_farm(field_id)?;
        let mut extra = BTreeMap::new();
        extra.insert("farm_id".into(), json!(with_farm.farm.id));
        let scheduled = schedule_destroy(
            &self.pool,
            "Field",
            field_id,
            with_farm.field.user_id.unwrap_or(with_farm.farm.user_id.unwrap_or(0)),
            "",
            5000,
            extra,
        )
        .map_err(|err| {
            if err.downcast_ref::<AssociationInUseError>().is_some() {
                Box::new(AssociationInUseError) as Box<dyn std::error::Error + Send + Sync>
            } else {
                err
            }
        })?;
        Ok(json!({
            "undo_token": scheduled.undo_token,
            "metadata": scheduled.metadata,
            "expires_at": scheduled.expires_at,
        }))
    }
}

fn farm_entity_to_record(farm: FarmEntity) -> FarmRecord {
    FarmRecord {
        id: farm.id,
        name: farm.name,
        user_id: farm.user_id,
        is_reference: farm.is_reference,
        latitude: farm.latitude,
        longitude: farm.longitude,
        region: farm.region,
        created_at: farm.created_at,
        updated_at: farm.updated_at,
    }
}

fn map_field_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<FieldEntity> {
    Ok(FieldEntity {
        id: row.get(0)?,
        name: row.get(1)?,
        area: row.get(2)?,
        daily_fixed_cost: row.get(3)?,
        description: None,
        region: row.get(4)?,
        farm_id: row.get(5)?,
        user_id: row.get(6)?,
        created_at: row.get(7)?,
        updated_at: row.get(8)?,
    })
}
