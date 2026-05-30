//! Ruby: `Adapters::CultivationPlan::Sessions::PlanSaveSession` + template copy.

use crate::pool::SqlitePool;
use crate::crop::CropSqliteGateway;
use agrr_domain::crop::dtos::CropStageCopyInput;
use agrr_domain::crop::interactors::crop_stage_copy_interactor::CropStageCopyInteractor;
use agrr_domain::cultivation_plan::dtos::{
    PlanSaveEnsureUserCropsInput, PlanSaveEnsureUserFarmInput, PlanSaveEnsureUserFieldsInput,
    PublicPlanSaveFromSessionOutput, PublicPlanSaveWorkspace,
};
use agrr_domain::cultivation_plan::gateways::{
    PlanSaveCropLimitGateway, PlanSaveFarmGateway, PlanSaveFieldGateway, PlanSaveUserCropGateway,
    PublicPlanSaveTxnGateway,
};
use agrr_domain::cultivation_plan::interactors::{
    PlanSaveEnsureUserCropsInteractor, PlanSaveEnsureUserFarmInteractor,
    PlanSaveEnsureUserFieldsInteractor,
};
use agrr_domain::cultivation_plan::ports::PublicPlanSavePersistencePort;
use agrr_domain::shared::attr::{AttrMap, AttrValue};
use agrr_domain::shared::ports::{ClockPort, LoggerPort, TranslateOptions, TranslatorPort};
use time::OffsetDateTime;
use rusqlite::params;
use std::collections::HashMap;

use super::CultivationPlanSqliteGateway;

pub struct PublicPlanSavePersistenceSqliteAdapter {
    pool: SqlitePool,
}

impl PublicPlanSavePersistenceSqliteAdapter {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

struct PlanSaveFarmGw {
    pool: SqlitePool,
}

impl PlanSaveFarmGateway for PlanSaveFarmGw {
    fn find_reference_farm(
        &self,
        farm_id: Option<i64>,
    ) -> Result<
        Option<agrr_domain::cultivation_plan::dtos::PlanSaveReferenceFarmSnapshot>,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        let Some(farm_id) = farm_id else {
            return Ok(None);
        };
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, name, latitude, longitude, region, weather_location_id FROM farms WHERE id = ?1",
                params![farm_id],
                |row| {
                    Ok(agrr_domain::cultivation_plan::dtos::PlanSaveReferenceFarmSnapshot {
                        id: row.get(0)?,
                        name: row.get(1)?,
                        latitude: row.get(2)?,
                        longitude: row.get(3)?,
                        region: row.get(4)?,
                        weather_location_id: row.get(5)?,
                    })
                },
            )
            .optional()
            .map_err(Into::into)
        })
    }

    fn find_user_farm_by_source(
        &self,
        user_id: i64,
        source_farm_id: i64,
    ) -> Result<
        Option<agrr_domain::cultivation_plan::dtos::PlanSaveUserFarmSnapshot>,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, name, region FROM farms WHERE user_id = ?1 AND source_farm_id = ?2",
                params![user_id, source_farm_id],
                |row| {
                    Ok(agrr_domain::cultivation_plan::dtos::PlanSaveUserFarmSnapshot {
                        id: row.get(0)?,
                        name: row.get(1)?,
                        region: row.get(2)?,
                    })
                },
            )
            .optional()
            .map_err(Into::into)
        })
    }

    fn count_non_reference_farms(&self, user_id: i64) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM farms WHERE user_id = ?1 AND is_reference = 0",
                params![user_id],
                |r| r.get(0),
            )
        })
    }

    fn create_user_farm_from_reference(
        &self,
        user_id: i64,
        reference_farm_id: i64,
        copy_name_suffix: &str,
    ) -> Result<
        agrr_domain::cultivation_plan::dtos::PlanSaveUserFarmSnapshot,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        let reference = self
            .find_reference_farm(Some(reference_farm_id))?
            .ok_or_else(|| format!("reference farm {reference_farm_id} not found"))?;
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO farms (user_id, name, latitude, longitude, region, is_reference, weather_location_id, source_farm_id, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, 0, ?6, ?7, datetime('now'), datetime('now'))",
                params![
                    user_id,
                    format!(
                        "{} (コピー {copy_name_suffix})",
                        reference.name.as_deref().unwrap_or("")
                    ),
                    reference.latitude,
                    reference.longitude,
                    reference.region,
                    reference.weather_location_id,
                    reference_farm_id,
                ],
            )?;
            let id = conn.last_insert_rowid();
            Ok(agrr_domain::cultivation_plan::dtos::PlanSaveUserFarmSnapshot {
                id,
                name: Some(format!(
                    "{} (コピー {copy_name_suffix})",
                    reference.name.as_deref().unwrap_or("")
                )),
                region: reference.region,
            })
        })
    }

    fn find_owned_farm_record(
        &self,
        user_id: i64,
        farm_id: i64,
    ) -> Result<Option<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let id: Option<i64> = conn
                .query_row(
                    "SELECT id FROM farms WHERE id = ?1 AND user_id = ?2",
                    params![farm_id, user_id],
                    |r| r.get(0),
                )
                .ok();
            Ok(id.map(|i| serde_json::json!({"id": i})))
        })
    }

    fn find_owned_private_plan_record(
        &self,
        user_id: i64,
        farm_id: i64,
    ) -> Result<Option<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let id: Option<i64> = conn
                .query_row(
                    "SELECT id FROM cultivation_plans WHERE plan_type = 'private' AND farm_id = ?1 AND user_id = ?2 LIMIT 1",
                    params![farm_id, user_id],
                    |r| r.get(0),
                )
                .ok();
            Ok(id.map(|i| serde_json::json!({"id": i})))
        })
    }
}

struct PlanSaveFieldGw {
    pool: SqlitePool,
}

impl PlanSaveFieldGateway for PlanSaveFieldGw {
    fn list_by_farm_id(
        &self,
        farm_id: i64,
        user_id: i64,
    ) -> Result<Vec<agrr_domain::cultivation_plan::dtos::PlanSaveFieldSnapshot>, Box<dyn std::error::Error + Send + Sync>>
    {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, name, area, farm_id, user_id FROM fields WHERE farm_id = ?1 AND user_id = ?2 ORDER BY id",
            )?;
            let rows = stmt.query_map(params![farm_id, user_id], |row| {
                Ok(agrr_domain::cultivation_plan::dtos::PlanSaveFieldSnapshot {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    area: row.get(2)?,
                    farm_id: row.get(3)?,
                    user_id: row.get(4)?,
                })
            })?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    fn create(
        &self,
        farm_id: i64,
        user_id: i64,
        attributes: AttrMap,
    ) -> Result<agrr_domain::cultivation_plan::dtos::PlanSaveFieldSnapshot, Box<dyn std::error::Error + Send + Sync>>
    {
        let name = match attributes.get("name") {
            Some(AttrValue::Str(s)) => s.clone(),
            _ => return Err("field name required".into()),
        };
        let area = match attributes.get("area") {
            Some(AttrValue::Str(s)) => s.parse().unwrap_or(0.0),
            Some(AttrValue::Int(i)) => *i as f64,
            _ => 0.0,
        };
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO fields (farm_id, user_id, name, area, created_at, updated_at) VALUES (?1, ?2, ?3, ?4, datetime('now'), datetime('now'))",
                params![farm_id, user_id, name, area],
            )?;
            let id = conn.last_insert_rowid();
            Ok(agrr_domain::cultivation_plan::dtos::PlanSaveFieldSnapshot {
                id,
                name: Some(name),
                area: Some(area),
                farm_id,
                user_id,
            })
        })
    }
}

struct PlanSaveUserCropGw {
    pool: SqlitePool,
}

impl PlanSaveUserCropGateway for PlanSaveUserCropGw {
    fn find_by_user_id_and_source_crop_id(
        &self,
        user_id: i64,
        source_crop_id: i64,
    ) -> Result<Option<agrr_domain::cultivation_plan::dtos::PlanSaveUserCropSnapshot>, Box<dyn std::error::Error + Send + Sync>>
    {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id FROM crops WHERE user_id = ?1 AND source_crop_id = ?2",
                params![user_id, source_crop_id],
                |row| Ok(agrr_domain::cultivation_plan::dtos::PlanSaveUserCropSnapshot { id: row.get(0)? }),
            )
            .optional()
            .map_err(Into::into)
        })
    }

    fn create(
        &self,
        user_id: i64,
        attributes: AttrMap,
    ) -> Result<agrr_domain::cultivation_plan::dtos::PlanSaveUserCropSnapshot, Box<dyn std::error::Error + Send + Sync>>
    {
        let mut cols = vec!["user_id"];
        let mut vals: Vec<AttrValue> = vec![AttrValue::Int(user_id)];
        for key in [
            "name",
            "variety",
            "area_per_unit",
            "revenue_per_area",
            "region",
            "source_crop_id",
        ] {
            if let Some(v) = attributes.get(key) {
                cols.push(key);
                vals.push(v.clone());
            }
        }
        if let Some(AttrValue::Bool(b)) = attributes.get("is_reference") {
            cols.push("is_reference");
            vals.push(AttrValue::Int(if *b { 1 } else { 0 }));
        }
        cols.push("created_at");
        cols.push("updated_at");
        let placeholders: Vec<_> = (0..cols.len()).map(|_| "?").collect();
        let sql = format!(
            "INSERT INTO crops ({}) VALUES ({}, datetime('now'), datetime('now'))",
            cols.join(", "),
            placeholders[..cols.len() - 2].join(", ")
        );
        self.pool.with_write_box(|conn| {
            let params: Vec<rusqlite::types::Value> = vals
                .iter()
                .map(|v| match v {
                    AttrValue::Str(s) => rusqlite::types::Value::Text(s.clone()),
                    AttrValue::Int(i) => rusqlite::types::Value::Integer(*i),
                    AttrValue::Bool(b) => rusqlite::types::Value::Integer(if *b { 1 } else { 0 }),
                    AttrValue::Null => rusqlite::types::Value::Null,
                })
                .collect();
            conn.execute(&sql, rusqlite::params_from_iter(params.iter()))?;
            let id = conn.last_insert_rowid();
            Ok(agrr_domain::cultivation_plan::dtos::PlanSaveUserCropSnapshot { id })
        })
    }
}

struct CropLimitGw {
    pool: SqlitePool,
}

impl PlanSaveCropLimitGateway for CropLimitGw {
    fn count_user_owned_non_reference_crops(
        &self,
        user_id: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM crops WHERE user_id = ?1 AND is_reference = 0",
                params![user_id],
                |r| r.get(0),
            )
        })
    }
}

impl PublicPlanSavePersistencePort for PublicPlanSavePersistenceSqliteAdapter {
    fn execute_save(
        &self,
        workspace: &PublicPlanSaveWorkspace,
    ) -> Result<PublicPlanSaveFromSessionOutput, Box<dyn std::error::Error + Send + Sync>> {
        let user_id = workspace.user_id;
        let session = &workspace.session_data;
        let plan_id = session.plan_id;
        let reference_farm_id = session
            .farm_id
            .ok_or_else(|| "missing farm_id".to_string())?;

        let farm_gw = PlanSaveFarmGw {
            pool: self.pool.clone(),
        };
        let logger = PlanSaveNoopLogger;
        let translator = PlanSavePassthroughTranslator;
        let clock = PlanSaveClock;
        let farm_interactor =
            PlanSaveEnsureUserFarmInteractor::new(&farm_gw, &logger, &translator, &clock);
        let farm_output = farm_interactor.call(PlanSaveEnsureUserFarmInput {
            user_id,
            reference_farm_id,
        })?;

        if farm_gw
            .find_owned_private_plan_record(user_id, farm_output.farm_id)?
            .is_some()
        {
            return Ok(PublicPlanSaveFromSessionOutput::success());
        }

        let field_gw = PlanSaveFieldGw {
            pool: self.pool.clone(),
        };
        let fields_interactor = PlanSaveEnsureUserFieldsInteractor::new(
            &field_gw,
            &logger,
            &translator,
        );
        let _field_output = fields_interactor.call(PlanSaveEnsureUserFieldsInput {
            user_id,
            farm_id: farm_output.farm_id,
            farm_reused: farm_output.farm_reused,
            field_data: session.field_data.clone(),
        })?;

        let crop_gw = PlanSaveUserCropGw {
            pool: self.pool.clone(),
        };
        let limit_gw = CropLimitGw {
            pool: self.pool.clone(),
        };
        let read_gw = super::PublicPlanSaveReadSqliteGateway::new(self.pool.clone());
        let crops_interactor = PlanSaveEnsureUserCropsInteractor::new(
            &read_gw,
            &crop_gw,
            &limit_gw,
            &logger,
            &translator,
        );
        let crop_output = crops_interactor.call(PlanSaveEnsureUserCropsInput {
            user_id,
            plan_id,
        })?;

        let crop_gateway = CropSqliteGateway::new(self.pool.clone());
        let stage_copy = CropStageCopyInteractor::new(&crop_gateway);
        for pair in &crop_output.stage_copy_pairs {
            stage_copy.call(CropStageCopyInput {
                reference_crop_id: pair.reference_crop_id,
                new_crop_id: pair.new_crop_id,
            })?;
        }

        let new_plan_id = copy_private_plan_from_public(
            &self.pool,
            user_id,
            farm_output.farm_id,
            plan_id,
            &crop_output.ref_cpc_id_to_user_crop_id,
        )?;

        let _ = new_plan_id;
        Ok(PublicPlanSaveFromSessionOutput::success())
    }
}

fn copy_private_plan_from_public(
    pool: &SqlitePool,
    user_id: i64,
    farm_id: i64,
    reference_plan_id: i64,
    ref_cpc_to_user_crop: &HashMap<i64, i64>,
) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
    pool.with_write_box(|conn| {
        let (total_area, plan_name, predicted_weather): (f64, Option<String>, Option<String>) =
            conn.query_row(
                "SELECT total_area, plan_name, predicted_weather_data FROM cultivation_plans WHERE id = ?1",
                params![reference_plan_id],
                |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
            )?;
        conn.execute(
            "INSERT INTO cultivation_plans (farm_id, user_id, total_area, plan_type, plan_name, status, predicted_weather_data, created_at, updated_at) \
             VALUES (?1, ?2, ?3, 'private', ?4, 'pending', ?5, datetime('now'), datetime('now'))",
            params![farm_id, user_id, total_area, plan_name, predicted_weather],
        )?;
        let new_plan_id = conn.last_insert_rowid();

        let mut field_map: HashMap<i64, i64> = HashMap::new();
        let mut stmt = conn.prepare(
            "SELECT id, name, area, daily_fixed_cost, description FROM cultivation_plan_fields WHERE cultivation_plan_id = ?1",
        )?;
        let fields = stmt.query_map(params![reference_plan_id], |row| {
            Ok((
                row.get::<_, i64>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, f64>(2)?,
                row.get::<_, f64>(3)?,
                row.get::<_, Option<String>>(4)?,
            ))
        })?;
        for field in fields {
            let (old_id, name, area, daily_fixed_cost, description) = field?;
            conn.execute(
                "INSERT INTO cultivation_plan_fields (cultivation_plan_id, name, area, daily_fixed_cost, description, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, datetime('now'), datetime('now'))",
                params![new_plan_id, name, area, daily_fixed_cost, description],
            )?;
            field_map.insert(old_id, conn.last_insert_rowid());
        }

        let mut cpc_map: HashMap<i64, i64> = HashMap::new();
        let mut stmt = conn.prepare(
            "SELECT id, crop_id, name, variety, area_per_unit, revenue_per_area FROM cultivation_plan_crops WHERE cultivation_plan_id = ?1 ORDER BY id",
        )?;
        let cpcs = stmt.query_map(params![reference_plan_id], |row| {
            Ok((
                row.get::<_, i64>(0)?,
                row.get::<_, i64>(1)?,
                row.get::<_, String>(2)?,
                row.get::<_, Option<String>>(3)?,
                row.get::<_, f64>(4)?,
                row.get::<_, f64>(5)?,
            ))
        })?;
        for cpc in cpcs {
            let (old_cpc_id, _ref_crop_id, name, variety, area_per_unit, revenue_per_area) = cpc?;
            let user_crop_id = ref_cpc_to_user_crop.get(&old_cpc_id).copied().unwrap_or(0);
            if user_crop_id == 0 {
                continue;
            }
            conn.execute(
                "INSERT INTO cultivation_plan_crops (cultivation_plan_id, crop_id, name, variety, area_per_unit, revenue_per_area, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, datetime('now'), datetime('now'))",
                params![new_plan_id, user_crop_id, name, variety, area_per_unit, revenue_per_area],
            )?;
            cpc_map.insert(old_cpc_id, conn.last_insert_rowid());
        }

        let mut fc_map: HashMap<i64, i64> = HashMap::new();
        let mut stmt = conn.prepare(
            "SELECT id, cultivation_plan_field_id, cultivation_plan_crop_id, area, start_date, completion_date, cultivation_days, estimated_cost, status, optimization_result \
             FROM field_cultivations WHERE cultivation_plan_id = ?1",
        )?;
        let fcs = stmt.query_map(params![reference_plan_id], |row| {
            Ok((
                row.get::<_, i64>(0)?,
                row.get::<_, i64>(1)?,
                row.get::<_, i64>(2)?,
                row.get::<_, f64>(3)?,
                row.get::<_, Option<String>>(4)?,
                row.get::<_, Option<String>>(5)?,
                row.get::<_, Option<i64>>(6)?,
                row.get::<_, Option<f64>>(7)?,
                row.get::<_, String>(8)?,
                row.get::<_, Option<String>>(9)?,
            ))
        })?;
        for fc in fcs {
            let (
                old_fc_id,
                old_field_id,
                old_cpc_id,
                area,
                start_date,
                completion_date,
                cultivation_days,
                estimated_cost,
                status,
                optimization_result,
            ) = fc?;
            let new_field = field_map.get(&old_field_id).copied();
            let new_cpc = cpc_map.get(&old_cpc_id).copied();
            if new_field.is_none() || new_cpc.is_none() {
                continue;
            }
            conn.execute(
                "INSERT INTO field_cultivations (cultivation_plan_id, cultivation_plan_field_id, cultivation_plan_crop_id, area, start_date, completion_date, cultivation_days, estimated_cost, status, optimization_result, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, datetime('now'), datetime('now'))",
                params![
                    new_plan_id,
                    new_field,
                    new_cpc,
                    area,
                    start_date,
                    completion_date,
                    cultivation_days,
                    estimated_cost,
                    status,
                    optimization_result,
                ],
            )?;
            fc_map.insert(old_fc_id, conn.last_insert_rowid());
        }

        Ok(new_plan_id)
    })
}

impl PublicPlanSaveTxnGateway for CultivationPlanSqliteGateway {
    fn within_transaction<F, T>(
        &self,
        block: F,
    ) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
    where
        F: FnOnce() -> Result<T, Box<dyn std::error::Error + Send + Sync>>,
    {
        block()
    }
}

struct PlanSaveNoopLogger;
impl LoggerPort for PlanSaveNoopLogger {
    fn info(&self, _message: &str) {}
    fn warn(&self, _message: &str) {}
    fn error(&self, _message: &str) {}
    fn debug(&self, _message: &str) {}
}

struct PlanSavePassthroughTranslator;
impl TranslatorPort for PlanSavePassthroughTranslator {
    fn translate(&self, key: &str, _options: &TranslateOptions) -> String {
        key.to_string()
    }

    fn localize(
        &self,
        date: time::Date,
        _format: Option<&str>,
        _options: &TranslateOptions,
    ) -> String {
        date.to_string()
    }
}

struct PlanSaveClock;
impl ClockPort for PlanSaveClock {
    fn today(&self) -> time::Date {
        OffsetDateTime::now_utc().date()
    }

    fn now(&self) -> OffsetDateTime {
        OffsetDateTime::now_utc()
    }
}

trait OptionalRow<T> {
    fn optional(self) -> Result<Option<T>, rusqlite::Error>;
}

impl<T> OptionalRow<T> for Result<T, rusqlite::Error> {
    fn optional(self) -> Result<Option<T>, rusqlite::Error> {
        match self {
            Ok(v) => Ok(Some(v)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e),
        }
    }
}
