//! Ruby: `Adapters::CultivationPlan::Gateways::PublicPlanSaveReadActiveRecordGateway`

use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::{
    PublicPlanSaveAgriculturalTaskReferenceRow, PublicPlanSaveCropReferenceRow,
    PublicPlanSaveFertilizeReferenceRow, PublicPlanSaveFieldDatum, PublicPlanSaveHeaderSnapshot,
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
        _plan_id: i64,
        region: Option<&str>,
    ) -> Result<Vec<PublicPlanSavePestReferenceRow>, Box<dyn std::error::Error + Send + Sync>> {
        let _ = region;
        Ok(vec![])
    }

    fn list_pesticide_reference_rows(
        &self,
        _region: Option<&str>,
    ) -> Result<Vec<PublicPlanSavePesticideReferenceRow>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
    }

    fn list_fertilize_reference_rows(
        &self,
        _region: Option<&str>,
    ) -> Result<Vec<PublicPlanSaveFertilizeReferenceRow>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(vec![])
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
        _region: Option<&str>,
    ) -> Result<Vec<PublicPlanSaveAgriculturalTaskReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
    {
        Ok(vec![])
    }

    fn list_interaction_rule_reference_rows(
        &self,
        _region: Option<&str>,
    ) -> Result<Vec<PublicPlanSaveInteractionRuleReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
    {
        Ok(vec![])
    }
}
