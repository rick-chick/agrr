//! Parity: `test/adapters/cultivation_plan/gateways/public_plan_save_read_active_record_gateway_test.rb`

use super::public_plan_save_read_gateway::PublicPlanSaveReadSqliteGateway;
use super::public_plan_save_read_gateway_test_fixture::{read_gateway_test_pool, seed_plan_and_crop};
use agrr_domain::cultivation_plan::gateways::PublicPlanSaveReadGateway;
use rusqlite::params;

fn gateway(pool: &crate::pool::SqlitePool) -> PublicPlanSaveReadSqliteGateway {
    PublicPlanSaveReadSqliteGateway::new(pool.clone())
}

#[test]
fn list_pest_reference_rows_returns_empty_when_plan_missing() {
    let pool = read_gateway_test_pool();
    let gw = gateway(&pool);
    let rows = gw.list_pest_reference_rows(-1, Some("jp")).unwrap();
    assert!(rows.is_empty());
}

#[test]
fn list_pest_reference_rows_returns_pest_wires_with_linked_crop_ids() {
    let pool = read_gateway_test_pool();
    let seed = seed_plan_and_crop(&pool);
    let gw = gateway(&pool);

    let pest_id = pool
        .with_write(|conn| {
            conn.execute(
                "INSERT INTO pests (user_id, name, is_reference, region, created_at, updated_at)
                 VALUES (NULL, 'ReadGwPest', 1, 'jp', datetime('now'), datetime('now'))",
                [],
            )?;
            let pest_id = conn.last_insert_rowid();
            conn.execute(
                "INSERT INTO crop_pests (crop_id, pest_id, created_at, updated_at)
                 VALUES (?1, ?2, datetime('now'), datetime('now'))",
                params![seed.ref_crop_id, pest_id],
            )?;
            Ok(pest_id)
        })
        .unwrap();

    let rows = gw
        .list_pest_reference_rows(seed.plan_id, Some("jp"))
        .unwrap();
    let row = rows
        .iter()
        .find(|r| r.reference_pest_id == pest_id)
        .expect("pest row");
    assert_eq!(Some("ReadGwPest".to_string()), row.name);
    assert!(row.linked_reference_crop_ids.contains(&seed.ref_crop_id));
}

#[test]
fn list_pesticide_reference_rows_returns_nested_rows_and_region_filter() {
    let pool = read_gateway_test_pool();
    let seed = seed_plan_and_crop(&pool);
    let gw = gateway(&pool);

    let (jp_pesticide_id, us_pesticide_id) = pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO pests (user_id, name, is_reference, region, created_at, updated_at)
             VALUES (NULL, 'ReadGwPzPest', 1, 'jp', datetime('now'), datetime('now'))",
            [],
        )?;
        let pest_id = conn.last_insert_rowid();
        conn.execute(
            "INSERT INTO pesticides (user_id, crop_id, pest_id, name, active_ingredient, is_reference, region, created_at, updated_at)
             VALUES (NULL, ?1, ?2, 'ReadGwPz', 'AI', 1, 'jp', datetime('now'), datetime('now'))",
            params![seed.ref_crop_id, pest_id],
        )?;
        let jp_id = conn.last_insert_rowid();
        conn.execute(
            "INSERT INTO pesticide_usage_constraints (pesticide_id, min_temperature, max_temperature, max_application_count, created_at, updated_at)
             VALUES (?1, 5.0, 35.0, 2, datetime('now'), datetime('now'))",
            params![jp_id],
        )?;
        conn.execute(
            "INSERT INTO pesticide_application_details (pesticide_id, dilution_ratio, amount_per_m2, amount_unit, application_method, created_at, updated_at)
             VALUES (?1, '500倍', 2.0, 'g', '灌注', datetime('now'), datetime('now'))",
            params![jp_id],
        )?;
        conn.execute(
            "INSERT INTO pesticides (user_id, crop_id, pest_id, name, is_reference, region, created_at, updated_at)
             VALUES (NULL, ?1, ?2, 'ReadGwPzUs', 1, 'us', datetime('now'), datetime('now'))",
            params![seed.ref_crop_id, pest_id],
        )?;
        let us_id = conn.last_insert_rowid();
        Ok((jp_id, us_id))
    }).unwrap();

    let rows = gw.list_pesticide_reference_rows(Some("jp")).unwrap();
    let row = rows
        .iter()
        .find(|r| r.reference_pesticide_id == jp_pesticide_id)
        .expect("jp pesticide");
    assert_eq!(Some("ReadGwPz".to_string()), row.name);
    assert_eq!(seed.ref_crop_id, row.reference_crop_id);
    assert_eq!(Some("AI".to_string()), row.active_ingredient);
    let uc = row.usage_constraint.as_ref().expect("usage_constraint");
    assert!((5.0 - uc.min_temperature.unwrap()).abs() < 0.0001);
    let ad = row.application_detail.as_ref().expect("application_detail");
    assert_eq!(Some("500倍".to_string()), ad.dilution_ratio);
    assert!(
        rows.iter()
            .all(|r| r.reference_pesticide_id != us_pesticide_id)
    );
}

#[test]
fn list_fertilize_reference_rows_returns_reference_fertilizes_for_region() {
    let pool = read_gateway_test_pool();
    let _seed = seed_plan_and_crop(&pool);
    let gw = gateway(&pool);

    let (jp_id, us_id) = pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO fertilizes (user_id, name, n, p, k, is_reference, region, created_at, updated_at)
             VALUES (NULL, 'ReadGwFert', 1.0, 2.0, 3.0, 1, 'jp', datetime('now'), datetime('now'))",
            [],
        )?;
        let jp = conn.last_insert_rowid();
        conn.execute(
            "INSERT INTO fertilizes (user_id, name, n, p, k, is_reference, region, created_at, updated_at)
             VALUES (NULL, 'ReadGwFertUs', 1.0, 1.0, 1.0, 1, 'us', datetime('now'), datetime('now'))",
            [],
        )?;
        let us = conn.last_insert_rowid();
        Ok((jp, us))
    }).unwrap();

    let rows = gw.list_fertilize_reference_rows(Some("jp")).unwrap();
    let row = rows
        .iter()
        .find(|r| r.reference_fertilize_id == jp_id)
        .expect("jp fertilize");
    assert_eq!(Some("ReadGwFert".to_string()), row.name);
    assert!((1.0 - row.n.unwrap()).abs() < 0.0001);
    assert!(rows.iter().all(|r| r.reference_fertilize_id != us_id));
}

#[test]
fn list_interaction_rule_reference_rows_without_rule_type_filter() {
    let pool = read_gateway_test_pool();
    let _seed = seed_plan_and_crop(&pool);
    let gw = gateway(&pool);

    let (jp_id, us_id, other_id) = pool.with_write(|conn| {
        conn.execute(
            "INSERT INTO interaction_rules (user_id, rule_type, source_group, target_group, impact_ratio, is_directional, is_reference, region, created_at, updated_at)
             VALUES (NULL, 'continuous_cultivation', 'ReadGwSrc', 'ReadGwTgt', 0.6, 1, 1, 'jp', datetime('now'), datetime('now'))",
            [],
        )?;
        let jp = conn.last_insert_rowid();
        conn.execute(
            "INSERT INTO interaction_rules (user_id, rule_type, source_group, target_group, impact_ratio, is_directional, is_reference, region, created_at, updated_at)
             VALUES (NULL, 'continuous_cultivation', 'ReadGwUsSrc', 'ReadGwUsTgt', 0.5, 1, 1, 'us', datetime('now'), datetime('now'))",
            [],
        )?;
        let us = conn.last_insert_rowid();
        conn.execute(
            "INSERT INTO interaction_rules (user_id, rule_type, source_group, target_group, impact_ratio, is_directional, is_reference, region, created_at, updated_at)
             VALUES (NULL, 'other_type', 'ReadGwOther', 'ReadGwOtherTgt', 0.5, 1, 1, 'jp', datetime('now'), datetime('now'))",
            [],
        )?;
        let other = conn.last_insert_rowid();
        Ok((jp, us, other))
    }).unwrap();

    let rows = gw.list_interaction_rule_reference_rows(Some("jp")).unwrap();
    let row = rows
        .iter()
        .find(|r| r.reference_interaction_rule_id == jp_id)
        .expect("jp rule");
    assert_eq!("ReadGwSrc", row.source_group);
    assert_eq!("ReadGwTgt", row.target_group);
    assert!(rows.iter().all(|r| r.reference_interaction_rule_id != us_id));
    assert!(
        rows.iter()
            .any(|r| r.reference_interaction_rule_id == other_id)
    );
}
