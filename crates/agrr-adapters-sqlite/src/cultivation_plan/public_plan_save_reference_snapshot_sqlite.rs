//! Rails `PublicPlanSaveReferenceSnapshotMapper` parity — row assembly for plan save read.

use agrr_domain::cultivation_plan::dtos::{
    PublicPlanSaveFertilizeReferenceRow, PublicPlanSaveInteractionRuleReferenceRow,
    PublicPlanSavePestControlMethodRow, PublicPlanSavePestReferenceRow,
    PublicPlanSavePestTemperatureProfileRow, PublicPlanSavePestThermalRequirementRow,
    PublicPlanSavePesticideApplicationDetailRow, PublicPlanSavePesticideReferenceRow,
    PublicPlanSavePesticideUsageConstraintRow,
};
use rusqlite::{params, Connection};

use super::public_plan_save_read_sql::reference_region_where;

pub(crate) fn load_pest_reference_rows(
    conn: &Connection,
    region: Option<&str>,
) -> rusqlite::Result<Vec<PublicPlanSavePestReferenceRow>> {
    let (where_clause, bind_region) = reference_region_where(region);
    let sql = format!(
        "SELECT id, name, name_scientific, family, \"order\", description, occurrence_season, region \
         FROM pests WHERE {where_clause} ORDER BY id"
    );
    let mut stmt = conn.prepare(&sql)?;
    let pest_rows = if bind_region {
        stmt.query_map(params![region.unwrap()], map_pest_main)?
    } else {
        stmt.query_map([], map_pest_main)?
    };

    let mut out = Vec::new();
    for pest in pest_rows {
        let (
            id,
            name,
            name_scientific,
            family,
            order,
            description,
            occurrence_season,
            region,
        ) = pest?;
        let temperature_profile = load_pest_temperature_profile(conn, id)?;
        let thermal_requirement = load_pest_thermal_requirement(conn, id)?;
        let control_methods = load_pest_control_methods(conn, id)?;
        let linked_reference_crop_ids = load_linked_crop_ids(conn, id)?;
        out.push(PublicPlanSavePestReferenceRow {
            reference_pest_id: id,
            name,
            name_scientific,
            family,
            order,
            description,
            occurrence_season,
            region,
            linked_reference_crop_ids,
            temperature_profile,
            thermal_requirement,
            control_methods,
        });
    }
    Ok(out)
}

fn map_pest_main(
    row: &rusqlite::Row<'_>,
) -> rusqlite::Result<(
    i64,
    Option<String>,
    Option<String>,
    Option<String>,
    Option<String>,
    Option<String>,
    Option<String>,
    Option<String>,
)> {
    Ok((
        row.get(0)?,
        row.get(1)?,
        row.get(2)?,
        row.get(3)?,
        row.get(4)?,
        row.get(5)?,
        row.get(6)?,
        row.get(7)?,
    ))
}

fn load_pest_temperature_profile(
    conn: &Connection,
    pest_id: i64,
) -> rusqlite::Result<Option<PublicPlanSavePestTemperatureProfileRow>> {
    match conn.query_row(
        "SELECT base_temperature, max_temperature FROM pest_temperature_profiles WHERE pest_id = ?1",
        params![pest_id],
        |row| {
            Ok(PublicPlanSavePestTemperatureProfileRow {
                base_temperature: row.get(0)?,
                max_temperature: row.get(1)?,
            })
        },
    ) {
        Ok(profile) => Ok(Some(profile)),
        Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
        Err(e) => Err(e),
    }
}

fn load_pest_thermal_requirement(
    conn: &Connection,
    pest_id: i64,
) -> rusqlite::Result<Option<PublicPlanSavePestThermalRequirementRow>> {
    match conn.query_row(
        "SELECT required_gdd, first_generation_gdd FROM pest_thermal_requirements WHERE pest_id = ?1",
        params![pest_id],
        |row| {
            Ok(PublicPlanSavePestThermalRequirementRow {
                required_gdd: row.get(0)?,
                first_generation_gdd: row.get(1)?,
            })
        },
    ) {
        Ok(thermal) => Ok(Some(thermal)),
        Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
        Err(e) => Err(e),
    }
}

fn load_pest_control_methods(
    conn: &Connection,
    pest_id: i64,
) -> rusqlite::Result<Vec<PublicPlanSavePestControlMethodRow>> {
    let mut stmt = conn.prepare(
        "SELECT method_type, method_name, description, timing_hint FROM pest_control_methods \
         WHERE pest_id = ?1 ORDER BY id",
    )?;
    let rows = stmt.query_map(params![pest_id], |row| {
        Ok(PublicPlanSavePestControlMethodRow {
            method_type: row.get(0)?,
            method_name: row.get(1)?,
            description: row.get(2)?,
            timing_hint: row.get(3)?,
        })
    })?;
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

fn load_linked_crop_ids(conn: &Connection, pest_id: i64) -> rusqlite::Result<Vec<i64>> {
    let mut stmt =
        conn.prepare("SELECT crop_id FROM crop_pests WHERE pest_id = ?1 ORDER BY crop_id")?;
    let rows = stmt.query_map(params![pest_id], |row| row.get(0))?;
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

pub(crate) fn load_pesticide_reference_rows(
    conn: &Connection,
    region: Option<&str>,
) -> rusqlite::Result<Vec<PublicPlanSavePesticideReferenceRow>> {
    let (where_clause, bind_region) = reference_region_where(region);
    let sql = format!(
        "SELECT p.id, p.crop_id, p.pest_id, p.name, p.active_ingredient, p.description, p.region, \
         uc.pesticide_id AS uc_pesticide_id, uc.min_temperature, uc.max_temperature, uc.max_wind_speed_m_s, \
         uc.max_application_count, uc.harvest_interval_days, uc.other_constraints, \
         ad.pesticide_id AS ad_pesticide_id, ad.dilution_ratio, ad.amount_per_m2, ad.amount_unit, ad.application_method \
         FROM pesticides p \
         LEFT JOIN pesticide_usage_constraints uc ON uc.pesticide_id = p.id \
         LEFT JOIN pesticide_application_details ad ON ad.pesticide_id = p.id \
         WHERE {where_clause} \
         ORDER BY p.id"
    );
    let mut stmt = conn.prepare(&sql)?;
    let rows = if bind_region {
        stmt.query_map(params![region.unwrap()], map_pesticide_row)?
    } else {
        stmt.query_map([], map_pesticide_row)?
    };
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

fn map_pesticide_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<PublicPlanSavePesticideReferenceRow> {
    let usage_constraint = match row.get::<_, Option<i64>>(7)? {
        Some(_) => Some(PublicPlanSavePesticideUsageConstraintRow::new(
            row.get(8)?,
            row.get(9)?,
            row.get(10)?,
            row.get(11)?,
            row.get(12)?,
            row.get(13)?,
        )),
        None => None,
    };
    let application_detail = match row.get::<_, Option<i64>>(14)? {
        Some(_) => Some(PublicPlanSavePesticideApplicationDetailRow::new(
            row.get(15)?,
            row.get(16)?,
            row.get(17)?,
            row.get(18)?,
        )),
        None => None,
    };
    Ok(PublicPlanSavePesticideReferenceRow::new(
        row.get(0)?,
        row.get(1)?,
        row.get(2)?,
        row.get(3)?,
        row.get(4)?,
        row.get(5)?,
        row.get(6)?,
        usage_constraint,
        application_detail,
    ))
}

pub(crate) fn load_fertilize_reference_rows(
    conn: &Connection,
    region: Option<&str>,
) -> rusqlite::Result<Vec<PublicPlanSaveFertilizeReferenceRow>> {
    let (where_clause, bind_region) = reference_region_where(region);
    let sql = format!(
        "SELECT id, name, n, p, k, description, package_size, region FROM fertilizes \
         WHERE {where_clause} ORDER BY id"
    );
    let mut stmt = conn.prepare(&sql)?;
    let rows = if bind_region {
        stmt.query_map(params![region.unwrap()], map_fertilize_row)?
    } else {
        stmt.query_map([], map_fertilize_row)?
    };
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

fn map_fertilize_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<PublicPlanSaveFertilizeReferenceRow> {
    Ok(PublicPlanSaveFertilizeReferenceRow {
        reference_fertilize_id: row.get(0)?,
        name: row.get(1)?,
        n: row.get(2)?,
        p: row.get(3)?,
        k: row.get(4)?,
        description: row.get(5)?,
        package_size: row.get(6)?,
        region: row.get(7)?,
    })
}

pub(crate) fn load_interaction_rule_reference_rows(
    conn: &Connection,
    region: Option<&str>,
) -> rusqlite::Result<Vec<PublicPlanSaveInteractionRuleReferenceRow>> {
    let (where_clause, bind_region) = reference_region_where(region);
    let sql = format!(
        "SELECT id, rule_type, source_group, target_group, impact_ratio, is_directional, region, description \
         FROM interaction_rules WHERE {where_clause} ORDER BY id"
    );
    let mut stmt = conn.prepare(&sql)?;
    let rows = if bind_region {
        stmt.query_map(params![region.unwrap()], map_interaction_rule_row)?
    } else {
        stmt.query_map([], map_interaction_rule_row)?
    };
    let mut out = Vec::new();
    for row in rows {
        out.push(row?);
    }
    Ok(out)
}

fn map_interaction_rule_row(
    row: &rusqlite::Row<'_>,
) -> rusqlite::Result<PublicPlanSaveInteractionRuleReferenceRow> {
    let is_directional: i64 = row.get(5)?;
    Ok(PublicPlanSaveInteractionRuleReferenceRow::new(
        row.get(0)?,
        row.get::<_, String>(1)?,
        row.get::<_, String>(2)?,
        row.get::<_, String>(3)?,
        row.get(4)?,
        is_directional != 0,
        row.get(6)?,
        row.get(7)?,
    ))
}
