mod support;

use support::{apply_repair, count_query, TestDb};

fn seed_india_inline_crops_without_stages(conn: &rusqlite::Connection) {
    conn.execute_batch(
        "INSERT INTO crops (name, variety, is_reference, user_id, region, groups, area_per_unit, revenue_per_area, created_at, updated_at)
         VALUES ('कपास', 'बीटी कपास', 1, NULL, 'in', '[\"Malvaceae\"]', 0.25, 12000.0, datetime('now'), datetime('now'));",
    )
    .unwrap();
}

#[test]
fn data_repair_india_reference_crops_restores_stages_from_fixture() {
    let db = TestDb::new();
    let conn = db.conn();
    seed_india_inline_crops_without_stages(&conn);

    let stages_before = count_query(
        &conn,
        "SELECT COUNT(*) FROM crop_stages cs
         INNER JOIN crops c ON c.id = cs.crop_id
         WHERE c.region = 'in' AND c.is_reference = 1",
    );
    assert_eq!(0, stages_before);

    apply_repair(&db.paths, "in", "repair_india_reference_crops");

    let crops = count_query(
        &conn,
        "SELECT COUNT(*) FROM crops WHERE region = 'in' AND is_reference = 1",
    );
    assert!(
        crops >= 30,
        "repair should load India reference crops from india_reference_crops.json"
    );

    let without_stages = count_query(
        &conn,
        "SELECT COUNT(*) FROM crops c
         WHERE c.region = 'in' AND c.is_reference = 1
           AND NOT EXISTS (SELECT 1 FROM crop_stages cs WHERE cs.crop_id = c.id)",
    );
    assert_eq!(
        0, without_stages,
        "every in reference crop must have crop_stages after repair"
    );

    let cotton_stages = count_query(
        &conn,
        "SELECT COUNT(*) FROM crop_stages cs
         INNER JOIN crops c ON c.id = cs.crop_id
         WHERE c.region = 'in' AND c.is_reference = 1 AND c.name LIKE '%कपास%'",
    );
    assert!(
        cotton_stages >= 3,
        "cotton reference crop should have growth stages"
    );
}

#[test]
fn data_repair_india_reference_crops_is_idempotent() {
    let db = TestDb::new();
    seed_india_inline_crops_without_stages(&db.conn());

    apply_repair(&db.paths, "in", "repair_india_reference_crops");
    apply_repair(&db.paths, "in", "repair_india_reference_crops");

    let conn = db.conn();
    let crops = count_query(
        &conn,
        "SELECT COUNT(*) FROM crops WHERE region = 'in' AND is_reference = 1",
    );
    assert!(crops >= 30);
    let without_stages = count_query(
        &conn,
        "SELECT COUNT(*) FROM crops c
         WHERE c.region = 'in' AND c.is_reference = 1
           AND NOT EXISTS (SELECT 1 FROM crop_stages cs WHERE cs.crop_id = c.id)",
    );
    assert_eq!(0, without_stages);
}
