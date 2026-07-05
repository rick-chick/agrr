//! Inline SQLite gateways for public plan save (Ruby `PlanSave*ActiveRecordGateway` parity).

use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::{
    CropTaskScheduleBlueprintCreateAttrs, CropTaskScheduleBlueprintRow,
    PlanSaveFieldSnapshot, PlanSaveReferenceFarmSnapshot,
    PlanSaveUserAgriculturalTaskSnapshot, PlanSaveUserCropSnapshot, PlanSaveUserFarmSnapshot,
    PlanSaveUserFertilizeSnapshot, PlanSaveUserInteractionRuleSnapshot, PlanSaveUserPestSnapshot,
    PlanSaveUserPesticideSnapshot,
};
use agrr_domain::cultivation_plan::gateways::{
    CropTaskScheduleBlueprintGateway, PlanSaveCropLimitGateway, PlanSaveFarmGateway,
    PlanSaveFieldGateway, PlanSaveUserAgriculturalTaskGateway, PlanSaveUserCropGateway,
    PlanSaveUserFertilizeGateway, PlanSaveUserInteractionRuleGateway, PlanSaveUserPestGateway,
    PlanSaveUserPesticideGateway,
};
use agrr_domain::shared::attr::{AttrMap, AttrValue};
use agrr_domain::cultivation_plan::errors::PlanSaveRecordNotFoundError;
use rusqlite::params;
use rust_decimal::Decimal;
use std::str::FromStr;

use super::plan_save_support::{
    insert_child_from_attr_map, insert_from_attr_map, update_from_attr_map, OptionalRow,
};

macro_rules! plan_save_gw {
    ($name:ident) => {
        pub(crate) struct $name {
            pub pool: SqlitePool,
        }

        impl $name {
            pub fn new(pool: SqlitePool) -> Self {
                Self { pool }
            }
        }
    };
}

plan_save_gw!(PlanSaveFarmGw);
plan_save_gw!(PlanSaveFieldGw);
plan_save_gw!(PlanSaveUserCropGw);
plan_save_gw!(CropLimitGw);
plan_save_gw!(PlanSaveUserPestGw);
plan_save_gw!(PlanSaveUserFertilizeGw);
plan_save_gw!(PlanSaveUserPesticideGw);
plan_save_gw!(PlanSaveUserAgriculturalTaskGw);
plan_save_gw!(PlanSaveUserInteractionRuleGw);
plan_save_gw!(CropTaskScheduleBlueprintGw);

impl PlanSaveFarmGateway for PlanSaveFarmGw {
    fn find_reference_farm(
        &self,
        farm_id: Option<i64>,
    ) -> Result<Option<PlanSaveReferenceFarmSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
        let Some(farm_id) = farm_id else {
            return Ok(None);
        };
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, name, latitude, longitude, region, weather_location_id FROM farms WHERE id = ?1",
                params![farm_id],
                |row| {
                    Ok(PlanSaveReferenceFarmSnapshot {
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
    ) -> Result<Option<PlanSaveUserFarmSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, name, region FROM farms WHERE user_id = ?1 AND source_farm_id = ?2",
                params![user_id, source_farm_id],
                |row| {
                    Ok(PlanSaveUserFarmSnapshot {
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
    ) -> Result<PlanSaveUserFarmSnapshot, Box<dyn std::error::Error + Send + Sync>> {
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
            Ok(PlanSaveUserFarmSnapshot {
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
                .optional()?;
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
                .optional()?;
            Ok(id.map(|i| serde_json::json!({"id": i})))
        })
    }
}

impl PlanSaveFieldGateway for PlanSaveFieldGw {
    fn list_by_farm_id(
        &self,
        farm_id: i64,
        user_id: i64,
    ) -> Result<Vec<PlanSaveFieldSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, name, area, farm_id, user_id FROM fields WHERE farm_id = ?1 AND user_id = ?2 ORDER BY id",
            )?;
            let rows = stmt.query_map(params![farm_id, user_id], |row| {
                Ok(PlanSaveFieldSnapshot {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    area: row.get(2)?,
                    farm_id: row.get(3)?,
                    user_id: row.get(4)?,
                })
            })?;
            rows.collect::<Result<Vec<_>, _>>().map_err(Into::into)
        })
    }

    fn create(
        &self,
        farm_id: i64,
        user_id: i64,
        attributes: AttrMap,
    ) -> Result<PlanSaveFieldSnapshot, Box<dyn std::error::Error + Send + Sync>> {
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
            Ok(PlanSaveFieldSnapshot {
                id,
                name: Some(name),
                area: Some(area),
                farm_id,
                user_id,
            })
        })
    }
}

impl PlanSaveUserCropGateway for PlanSaveUserCropGw {
    fn find_by_user_id_and_source_crop_id(
        &self,
        user_id: i64,
        source_crop_id: i64,
    ) -> Result<Option<PlanSaveUserCropSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id FROM crops WHERE user_id = ?1 AND source_crop_id = ?2",
                params![user_id, source_crop_id],
                |row| Ok(PlanSaveUserCropSnapshot { id: row.get(0)? }),
            )
            .optional()
            .map_err(Into::into)
        })
    }

    fn create(
        &self,
        user_id: i64,
        attributes: AttrMap,
    ) -> Result<PlanSaveUserCropSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        let mut attrs = attributes;
        attrs.insert("user_id".into(), AttrValue::Int(user_id));
        if !attrs.contains_key("is_reference") {
            attrs.insert("is_reference".into(), AttrValue::Int(0));
        } else if let Some(AttrValue::Bool(b)) = attrs.get("is_reference") {
            attrs.insert("is_reference".into(), AttrValue::Int(if *b { 1 } else { 0 }));
        }
        self.pool.with_write_box(|conn| {
            let id = insert_from_attr_map(conn, "crops", &attrs)?;
            Ok(PlanSaveUserCropSnapshot { id })
        })
    }
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

impl PlanSaveUserPestGateway for PlanSaveUserPestGw {
    fn find_by_user_id_and_source_pest_id(
        &self,
        user_id: i64,
        source_pest_id: i64,
    ) -> Result<Option<PlanSaveUserPestSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, name FROM pests WHERE user_id = ?1 AND source_pest_id = ?2",
                params![user_id, source_pest_id],
                |row| {
                    Ok(PlanSaveUserPestSnapshot {
                        id: row.get(0)?,
                        name: row.get(1)?,
                    })
                },
            )
            .optional()
            .map_err(Into::into)
        })
    }

    fn create(
        &self,
        user_id: i64,
        attributes: AttrMap,
    ) -> Result<PlanSaveUserPestSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        let mut attrs = attributes;
        attrs.insert("user_id".into(), AttrValue::Int(user_id));
        if let Some(AttrValue::Bool(b)) = attrs.get("is_reference") {
            attrs.insert("is_reference".into(), AttrValue::Int(if *b { 1 } else { 0 }));
        }
        self.pool.with_write_box(|conn| {
            let id = insert_from_attr_map(conn, "pests", &attrs)?;
            let name: Option<String> = conn
                .query_row("SELECT name FROM pests WHERE id = ?1", params![id], |r| r.get(0))
                .optional()?;
            Ok(PlanSaveUserPestSnapshot { id, name })
        })
    }

    fn create_temperature_profile(&self, pest_id: i64, attributes: AttrMap) {
        let _ = self.pool.with_write(|conn| {
            insert_child_from_attr_map(conn, "pest_temperature_profiles", "pest_id", pest_id, &attributes)
        });
    }

    fn create_thermal_requirement(&self, pest_id: i64, attributes: AttrMap) {
        let _ = self.pool.with_write(|conn| {
            insert_child_from_attr_map(conn, "pest_thermal_requirements", "pest_id", pest_id, &attributes)
        });
    }

    fn create_control_method(&self, pest_id: i64, attributes: AttrMap) {
        let _ = self.pool.with_write(|conn| {
            insert_child_from_attr_map(conn, "pest_control_methods", "pest_id", pest_id, &attributes)
        });
    }

    fn link_crop_pest(&self, crop_id: i64, pest_id: i64) {
        let _ = self.pool.with_write(|conn| {
            conn.execute(
                "INSERT OR IGNORE INTO crop_pests (crop_id, pest_id, created_at, updated_at) VALUES (?1, ?2, datetime('now'), datetime('now'))",
                params![crop_id, pest_id],
            )
        });
    }
}

impl PlanSaveUserFertilizeGateway for PlanSaveUserFertilizeGw {
    fn find_by_user_id_and_source_fertilize_id(
        &self,
        user_id: i64,
        source_fertilize_id: i64,
    ) -> Result<Option<PlanSaveUserFertilizeSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, name FROM fertilizes WHERE user_id = ?1 AND source_fertilize_id = ?2",
                params![user_id, source_fertilize_id],
                |row| {
                    Ok(PlanSaveUserFertilizeSnapshot {
                        id: row.get(0)?,
                        name: row.get(1)?,
                    })
                },
            )
            .optional()
            .map_err(Into::into)
        })
    }

    fn create(
        &self,
        user_id: i64,
        attributes: AttrMap,
    ) -> Result<PlanSaveUserFertilizeSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        let mut attrs = attributes;
        attrs.insert("user_id".into(), AttrValue::Int(user_id));
        if let Some(AttrValue::Bool(b)) = attrs.get("is_reference") {
            attrs.insert("is_reference".into(), AttrValue::Int(if *b { 1 } else { 0 }));
        }
        self.pool.with_write_box(|conn| {
            let id = insert_from_attr_map(conn, "fertilizes", &attrs)?;
            let name: Option<String> = conn
                .query_row("SELECT name FROM fertilizes WHERE id = ?1", params![id], |r| r.get(0))
                .optional()?;
            Ok(PlanSaveUserFertilizeSnapshot { id, name })
        })
    }
}

impl PlanSaveUserPesticideGateway for PlanSaveUserPesticideGw {
    fn find_by_user_id_and_source_pesticide_id(
        &self,
        user_id: i64,
        source_pesticide_id: i64,
    ) -> Result<Option<PlanSaveUserPesticideSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, name FROM pesticides WHERE user_id = ?1 AND source_pesticide_id = ?2",
                params![user_id, source_pesticide_id],
                |row| {
                    Ok(PlanSaveUserPesticideSnapshot {
                        id: row.get(0)?,
                        name: row.get(1)?,
                    })
                },
            )
            .optional()
            .map_err(Into::into)
        })
    }

    fn create(
        &self,
        user_id: i64,
        attributes: AttrMap,
        usage_constraint_attributes: Option<AttrMap>,
        application_detail_attributes: Option<AttrMap>,
    ) -> Result<PlanSaveUserPesticideSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        let mut attrs = attributes;
        attrs.insert("user_id".into(), AttrValue::Int(user_id));
        if let Some(AttrValue::Bool(b)) = attrs.get("is_reference") {
            attrs.insert("is_reference".into(), AttrValue::Int(if *b { 1 } else { 0 }));
        }
        self.pool.with_write_box(|conn| {
            let id = insert_from_attr_map(conn, "pesticides", &attrs)?;
            if let Some(usage) = usage_constraint_attributes {
                insert_child_from_attr_map(
                    conn,
                    "pesticide_usage_constraints",
                    "pesticide_id",
                    id,
                    &usage,
                )?;
            }
            if let Some(detail) = application_detail_attributes {
                insert_child_from_attr_map(
                    conn,
                    "pesticide_application_details",
                    "pesticide_id",
                    id,
                    &detail,
                )?;
            }
            let name: Option<String> = conn
                .query_row("SELECT name FROM pesticides WHERE id = ?1", params![id], |r| r.get(0))
                .optional()?;
            Ok(PlanSaveUserPesticideSnapshot { id, name })
        })
    }
}

impl PlanSaveUserAgriculturalTaskGateway for PlanSaveUserAgriculturalTaskGw {
    fn find_by_user_id_and_source_agricultural_task_id(
        &self,
        user_id: i64,
        source_agricultural_task_id: i64,
    ) -> Result<Option<PlanSaveUserAgriculturalTaskSnapshot>, Box<dyn std::error::Error + Send + Sync>>
    {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, name FROM agricultural_tasks WHERE user_id = ?1 AND source_agricultural_task_id = ?2",
                params![user_id, source_agricultural_task_id],
                |row| {
                    Ok(PlanSaveUserAgriculturalTaskSnapshot {
                        id: row.get(0)?,
                        name: row.get(1)?,
                    })
                },
            )
            .optional()
            .map_err(Into::into)
        })
    }

    fn create(
        &self,
        user_id: i64,
        attributes: AttrMap,
    ) -> Result<PlanSaveUserAgriculturalTaskSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        let mut attrs = attributes;
        attrs.insert("user_id".into(), AttrValue::Int(user_id));
        if let Some(AttrValue::Bool(b)) = attrs.get("is_reference") {
            attrs.insert("is_reference".into(), AttrValue::Int(if *b { 1 } else { 0 }));
        }
        self.pool.with_write_box(|conn| {
            let id = insert_from_attr_map(conn, "agricultural_tasks", &attrs)?;
            let name: Option<String> = conn
                .query_row(
                    "SELECT name FROM agricultural_tasks WHERE id = ?1",
                    params![id],
                    |r| r.get(0),
                )
                .optional()?;
            Ok(PlanSaveUserAgriculturalTaskSnapshot { id, name })
        })
    }
}

impl PlanSaveUserInteractionRuleGateway for PlanSaveUserInteractionRuleGw {
    fn find_by_user_id_and_source_interaction_rule_id(
        &self,
        user_id: i64,
        source_interaction_rule_id: i64,
    ) -> Result<Option<PlanSaveUserInteractionRuleSnapshot>, Box<dyn std::error::Error + Send + Sync>>
    {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, source_interaction_rule_id FROM interaction_rules WHERE user_id = ?1 AND source_interaction_rule_id = ?2 AND is_reference = 0",
                params![user_id, source_interaction_rule_id],
                |row| {
                    Ok(PlanSaveUserInteractionRuleSnapshot {
                        id: row.get(0)?,
                        source_interaction_rule_id: row.get(1)?,
                    })
                },
            )
            .optional()
            .map_err(Into::into)
        })
    }

    fn find_by_user_id_and_rule_type_and_source_group_and_target_group_and_region(
        &self,
        user_id: i64,
        rule_type: &str,
        source_group: &str,
        target_group: &str,
        region: Option<&str>,
    ) -> Result<Option<PlanSaveUserInteractionRuleSnapshot>, Box<dyn std::error::Error + Send + Sync>>
    {
        self.pool.with_read_box(|conn| {
            conn.query_row(
                "SELECT id, source_interaction_rule_id FROM interaction_rules \
                 WHERE user_id = ?1 AND rule_type = ?2 AND source_group = ?3 AND target_group = ?4 \
                 AND region IS ?5 AND is_reference = 0",
                params![user_id, rule_type, source_group, target_group, region],
                |row| {
                    Ok(PlanSaveUserInteractionRuleSnapshot {
                        id: row.get(0)?,
                        source_interaction_rule_id: row.get(1)?,
                    })
                },
            )
            .optional()
            .map_err(Into::into)
        })
    }

    fn update(
        &self,
        user_id: i64,
        interaction_rule_id: i64,
        attributes: AttrMap,
    ) -> Result<PlanSaveUserInteractionRuleSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            let exists: Option<i64> = conn
                .query_row(
                    "SELECT id FROM interaction_rules WHERE id = ?1 AND user_id = ?2 AND is_reference = 0",
                    params![interaction_rule_id, user_id],
                    |r| r.get(0),
                )
                .optional()?;
            if exists.is_none() {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            update_from_attr_map(conn, "interaction_rules", interaction_rule_id, &attributes)?;
            conn.query_row(
                "SELECT id, source_interaction_rule_id FROM interaction_rules WHERE id = ?1",
                params![interaction_rule_id],
                |row| {
                    Ok(PlanSaveUserInteractionRuleSnapshot {
                        id: row.get(0)?,
                        source_interaction_rule_id: row.get(1)?,
                    })
                },
            )
        })
        .map_err(|e| {
            if e.downcast_ref::<agrr_domain::shared::exceptions::RecordNotFoundError>().is_some() {
                Box::new(PlanSaveRecordNotFoundError(format!(
                    "InteractionRule not found: {interaction_rule_id}"
                ))) as Box<dyn std::error::Error + Send + Sync>
            } else {
                e
            }
        })
    }

    fn create(
        &self,
        user_id: i64,
        attributes: AttrMap,
    ) -> Result<PlanSaveUserInteractionRuleSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        let mut attrs = attributes;
        attrs.insert("user_id".into(), AttrValue::Int(user_id));
        if let Some(AttrValue::Bool(b)) = attrs.get("is_reference") {
            attrs.insert("is_reference".into(), AttrValue::Int(if *b { 1 } else { 0 }));
        }
        self.pool.with_write_box(|conn| {
            let id = insert_from_attr_map(conn, "interaction_rules", &attrs)?;
            let source_id: Option<i64> = conn
                .query_row(
                    "SELECT source_interaction_rule_id FROM interaction_rules WHERE id = ?1",
                    params![id],
                    |r| r.get(0),
                )
                .optional()?;
            Ok(PlanSaveUserInteractionRuleSnapshot {
                id,
                source_interaction_rule_id: source_id,
            })
        })
    }
}

impl CropTaskScheduleBlueprintGateway for CropTaskScheduleBlueprintGw {
    fn list_by_crop_id(
        &self,
        crop_id: i64,
    ) -> Result<Vec<CropTaskScheduleBlueprintRow>, Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_read_box(|conn| {
            let mut stmt = conn.prepare(
                "SELECT agricultural_task_id, source_agricultural_task_id, stage_order, stage_name, \
                 gdd_trigger, gdd_tolerance, task_type, source, priority, amount, amount_unit, \
                 description, weather_dependency, time_per_sqm \
                 FROM crop_task_schedule_blueprints WHERE crop_id = ?1 ORDER BY stage_order",
            )?;
            let rows = stmt.query_map(params![crop_id], |row| {
                let gdd_trigger: f64 = row.get(4)?;
                let gdd_tolerance: Option<f64> = row.get(5)?;
                let amount: Option<f64> = row.get(9)?;
                let time_per_sqm: Option<f64> = row.get(13)?;
                Ok(CropTaskScheduleBlueprintRow {
                    agricultural_task_id: row.get(0)?,
                    source_agricultural_task_id: row.get(1)?,
                    stage_order: row.get(2)?,
                    stage_name: row.get(3)?,
                    gdd_trigger: Decimal::from_str(&gdd_trigger.to_string()).ok(),
                    gdd_tolerance: gdd_tolerance
                        .and_then(|v| Decimal::from_str(&v.to_string()).ok()),
                    task_type: row.get(6)?,
                    source: row.get(7)?,
                    priority: row.get(8)?,
                    amount: amount.and_then(|v| Decimal::from_str(&v.to_string()).ok()),
                    amount_unit: row.get(10)?,
                    description: row.get(11)?,
                    weather_dependency: row.get(12)?,
                    time_per_sqm: time_per_sqm
                        .and_then(|v| Decimal::from_str(&v.to_string()).ok()),
                })
            })?;
            rows.collect::<Result<Vec<_>, _>>().map_err(Into::into)
        })
    }

    fn delete_by_crop_id(&self, crop_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.pool.with_write_box(|conn| {
            conn.execute(
                "DELETE FROM crop_task_schedule_blueprints WHERE crop_id = ?1",
                params![crop_id],
            )?;
            Ok(())
        })
    }

    fn bulk_create(
        &self,
        records: &[CropTaskScheduleBlueprintCreateAttrs],
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if records.is_empty() {
            return Ok(());
        }
        self.pool.with_write_box(|conn| {
            for rec in records {
                conn.execute(
                    "INSERT INTO crop_task_schedule_blueprints (crop_id, agricultural_task_id, source_agricultural_task_id, \
                     stage_order, stage_name, gdd_trigger, gdd_tolerance, task_type, source, priority, amount, amount_unit, \
                     description, weather_dependency, time_per_sqm, created_at, updated_at) \
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, datetime('now'), datetime('now'))",
                    params![
                        rec.crop_id,
                        rec.agricultural_task_id,
                        rec.source_agricultural_task_id,
                        rec.stage_order,
                        rec.stage_name,
                        rec.gdd_trigger,
                        rec.gdd_tolerance,
                        rec.task_type,
                        rec.source,
                        rec.priority,
                        rec.amount,
                        rec.amount_unit,
                        rec.description,
                        rec.weather_dependency,
                        rec.time_per_sqm,
                    ],
                )?;
            }
            Ok(())
        })
    }
}

pub(crate) fn resolve_agricultural_task_id(
    reference_task_id: i64,
    user_id: i64,
    map: &mut std::collections::HashMap<i64, i64>,
    gateway: &PlanSaveUserAgriculturalTaskGw,
) -> Result<Option<i64>, Box<dyn std::error::Error + Send + Sync>> {
    if let Some(id) = map.get(&reference_task_id) {
        return Ok(Some(*id));
    }
    let snapshot = gateway.find_by_user_id_and_source_agricultural_task_id(user_id, reference_task_id)?;
    if let Some(s) = snapshot {
        map.insert(reference_task_id, s.id);
        return Ok(Some(s.id));
    }
    Ok(None)
}
