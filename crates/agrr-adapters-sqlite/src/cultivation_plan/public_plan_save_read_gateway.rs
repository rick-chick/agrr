//! Ruby: `Adapters::CultivationPlan::Gateways::PublicPlanSaveReadActiveRecordGateway`

use crate::pool::SqlitePool;
use super::public_plan_save_read_sql::plan_exists;
use super::public_plan_save_reference_snapshot_sqlite::{
    load_fertilize_reference_rows, load_interaction_rule_reference_rows,
    load_pest_reference_rows, load_pesticide_reference_rows,
};
use agrr_domain::cultivation_plan::dtos::{
    PublicPlanSaveAgriculturalTaskReferenceRow, PublicPlanSaveCropReferenceRow,
    PublicPlanSaveFertilizeReferenceRow,
    PublicPlanSaveFieldDatum, PublicPlanSaveHeaderSnapshot,
    PublicPlanSaveInteractionRuleReferenceRow, PublicPlanSavePestReferenceRow,
    PublicPlanSavePesticideReferenceRow,
};
use agrr_domain::cultivation_plan::gateways::PublicPlanSaveReadGateway;
use rusqlite::params;

pub struct PublicPlanSaveReadSqliteGateway {
    pool: SqlitePool,
}

impl PublicPlanSaveReadSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn map_agricultural_task_row(
    row: &rusqlite::Row<'_>,
) -> rusqlite::Result<(
    i64,
    Option<String>,
    Option<String>,
    Option<f64>,
    Option<String>,
    Option<Vec<String>>,
    Option<String>,
    Option<String>,
    Option<String>,
)> {
    let tools_raw: Option<String> = row.get(5)?;
    Ok((
        row.get(0)?,
        row.get(1)?,
        row.get(2)?,
        row.get(3)?,
        row.get(4)?,
        parse_required_tools(tools_raw),
        row.get(6)?,
        row.get(7)?,
        row.get(8)?,
    ))
}

fn parse_required_tools(raw: Option<String>) -> Option<Vec<String>> {
    raw.and_then(|s| serde_json::from_str::<Vec<String>>(&s).ok())
}

fn load_blueprint_linked_crop_ids(
    conn: &rusqlite::Connection,
    reference_agricultural_task_id: i64,
) -> rusqlite::Result<Vec<i64>> {
    let mut stmt = conn.prepare(
        "SELECT DISTINCT crop_id FROM crop_task_schedule_blueprints \
         WHERE agricultural_task_id = ?1 OR source_agricultural_task_id = ?1 \
         ORDER BY crop_id",
    )?;
    let rows = stmt.query_map(params![reference_agricultural_task_id], |row| row.get(0))?;
    rows.collect()
}

impl PublicPlanSaveReadGateway for PublicPlanSaveReadSqliteGateway {
    fn find_header(
        &self,
        plan_id: i64,
    ) -> Result<Option<PublicPlanSaveHeaderSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, farm_id FROM cultivation_plans WHERE id = ?1 LIMIT 1",
            )?;
            let mut rows = stmt.query(params![plan_id])?;
            if let Some(row) = rows.next()? {
                let plan_id: i64 = row.get(0)?;
                let farm_id: i64 = row.get(1)?;
                return Ok(Some(PublicPlanSaveHeaderSnapshot::new(
                    plan_id,
                    Some(farm_id),
                )));
            }
            Ok(None)
        })
    }

    fn list_field_rows(
        &self,
        plan_id: i64,
    ) -> Result<Vec<PublicPlanSaveFieldDatum>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT name, area FROM cultivation_plan_fields WHERE cultivation_plan_id = ?1 ORDER BY id",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| {
                let name: Option<String> = row.get(0)?;
                let area: Option<f64> = row.get(1)?;
                // Rails mapper default when coordinates are not persisted on plan fields.
                let coordinates = vec![35.0, 139.0];
                Ok(PublicPlanSaveFieldDatum::new(name, area, coordinates))
            })?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    fn list_crop_reference_rows(
        &self,
        plan_id: i64,
    ) -> Result<Vec<PublicPlanSaveCropReferenceRow>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT cpc.id, c.id, c.name, c.variety, c.area_per_unit, c.revenue_per_area, c.groups, c.region, c.is_reference \
                 FROM cultivation_plan_crops cpc INNER JOIN crops c ON c.id = cpc.crop_id \
                 WHERE cpc.cultivation_plan_id = ?1 ORDER BY cpc.id",
            )?;
            let rows = stmt.query_map(params![plan_id], |row| {
                let groups_raw: Option<String> = row.get(6)?;
                let groups = groups_raw
                    .as_ref()
                    .and_then(|g| serde_json::from_str::<Vec<String>>(g).ok())
                    .or_else(|| groups_raw.map(|g| vec![g]));
                Ok(PublicPlanSaveCropReferenceRow {
                    cultivation_plan_crop_id: row.get(0)?,
                    reference_crop_id: row.get(1)?,
                    name: row.get(2)?,
                    variety: row.get(3)?,
                    area_per_unit: row.get(4)?,
                    revenue_per_area: row.get(5)?,
                    groups,
                    region: row.get(7)?,
                })
            })?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
    }

    fn list_pest_reference_rows(
        &self,
        plan_id: i64,
        region: Option<&str>,
    ) -> Result<Vec<PublicPlanSavePestReferenceRow>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            if !plan_exists(conn, plan_id)? {
                return Ok(vec![]);
            }
            load_pest_reference_rows(conn, region).map_err(Into::into)
        })
    }

    fn list_pesticide_reference_rows(
        &self,
        region: Option<&str>,
    ) -> Result<Vec<PublicPlanSavePesticideReferenceRow>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool
            .with_read_box(|conn| load_pesticide_reference_rows(conn, region).map_err(Into::into))
    }

    fn list_fertilize_reference_rows(
        &self,
        region: Option<&str>,
    ) -> Result<Vec<PublicPlanSaveFertilizeReferenceRow>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool
            .with_read_box(|conn| load_fertilize_reference_rows(conn, region).map_err(Into::into))
    }

    fn exists_fertilize_name(&self, name: &str) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
        if name.is_empty() {
            return Ok(false);
        }
        self.pool.with_read_box(|conn| {
            let n: i64 = conn.query_row(
                "SELECT COUNT(*) FROM fertilizes WHERE name = ?1",
                params![name],
                |r| r.get(0),
            )?;
            Ok(n > 0)
        })
    }

    fn list_agricultural_task_reference_rows(
        &self,
        region: Option<&str>,
    ) -> Result<Vec<PublicPlanSaveAgriculturalTaskReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
    {
        self.pool.with_read_box(|conn| {
            let (sql, region_param): (&str, Option<&str>) = match region {
                Some(r) => (
                    "SELECT id, name, description, time_per_sqm, weather_dependency, required_tools, skill_level, task_type, region \
                     FROM agricultural_tasks WHERE is_reference = 1 AND (region IS NULL OR region = ?1) ORDER BY id",
                    Some(r),
                ),
                None => (
                    "SELECT id, name, description, time_per_sqm, weather_dependency, required_tools, skill_level, task_type, region \
                     FROM agricultural_tasks WHERE is_reference = 1 ORDER BY id",
                    None,
                ),
            };
            let mut stmt = conn.prepare(sql)?;
            let task_rows = match region_param {
                Some(r) => stmt.query_map(params![r], map_agricultural_task_row)?,
                None => stmt.query_map([], map_agricultural_task_row)?,
            };
            let mut out = Vec::new();
            for task in task_rows {
                let (
                    task_id,
                    name,
                    description,
                    time_per_sqm,
                    weather_dependency,
                    required_tools,
                    skill_level,
                    task_type,
                    task_region,
                ) = task?;
                let linked_crop_ids = load_blueprint_linked_crop_ids(conn, task_id)?;
                out.push(PublicPlanSaveAgriculturalTaskReferenceRow {
                    reference_agricultural_task_id: task_id,
                    name,
                    description,
                    time_per_sqm,
                    weather_dependency,
                    required_tools,
                    skill_level,
                    task_type,
                    task_type_id: None,
                    region: task_region,
                    linked_reference_crop_ids: linked_crop_ids,
                });
            }
            Ok(out)
        })
    }

    fn list_interaction_rule_reference_rows(
        &self,
        region: Option<&str>,
    ) -> Result<Vec<PublicPlanSaveInteractionRuleReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
    {
        self.pool.with_read_box(|conn| {
            load_interaction_rule_reference_rows(conn, region).map_err(Into::into)
        })
    }
}
