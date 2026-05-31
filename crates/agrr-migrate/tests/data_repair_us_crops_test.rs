mod support;

use support::{apply_data, count_query, TestDb};

fn seed_us_inline_crops_without_stages(conn: &rusqlite::Connection) {
    let rows = [
        ("Almonds", "Nonpareil"),
        ("Apples", "Red Delicious"),
        ("Carrots", "Standard"),
        ("Cotton", "Upland Cotton"),
        ("Rice", "Long Grain"),
        ("Soybeans", "Standard"),
        ("Wheat", "Winter Wheat"),
    ];
    for (name, variety) in rows {
        conn.execute(
            "INSERT INTO crops (name, variety, is_reference, user_id, region, groups, area_per_unit, revenue_per_area, created_at, updated_at)
             VALUES (?1, ?2, 1, NULL, 'us', '[\"Poaceae\"]', 1.0, 500.0, datetime('now'), datetime('now'));",
            rusqlite::params![name, variety],
        )
        .unwrap();
    }
}

#[test]
fn data_repair_us_reference_crops_restores_stages_from_fixture() {
    let db = TestDb::new();
    let conn = db.conn();
    seed_us_inline_crops_without_stages(&conn);

    let stages_before = count_query(
        &conn,
        "SELECT COUNT(*) FROM crop_stages cs
         INNER JOIN crops c ON c.id = cs.crop_id
         WHERE c.region = 'us' AND c.is_reference = 1",
    );
    assert_eq!(0, stages_before);

    apply_data(&db.paths, "us", "repair");

    let crops = count_query(
        &conn,
        "SELECT COUNT(*) FROM crops WHERE region = 'us' AND is_reference = 1",
    );
    assert!(
        crops >= 30,
        "repair should load US reference crops from us_reference_crops.json"
    );

    let without_stages = count_query(
        &conn,
        "SELECT COUNT(*) FROM crops c
         WHERE c.region = 'us' AND c.is_reference = 1
           AND NOT EXISTS (SELECT 1 FROM crop_stages cs WHERE cs.crop_id = c.id)",
    );
    assert_eq!(
        0, without_stages,
        "every us reference crop must have crop_stages after repair"
    );

    let wheat_stages = count_query(
        &conn,
        "SELECT COUNT(*) FROM crop_stages cs
         INNER JOIN crops c ON c.id = cs.crop_id
         WHERE c.region = 'us' AND c.is_reference = 1 AND c.name = 'Wheat'",
    );
    assert!(
        wheat_stages >= 3,
        "wheat reference crop should have growth stages"
    );
}

#[test]
fn data_repair_us_reference_crops_is_idempotent() {
    let db = TestDb::new();
    seed_us_inline_crops_without_stages(&db.conn());

    apply_data(&db.paths, "us", "repair");
    apply_data(&db.paths, "us", "repair");

    let conn = db.conn();
    let without_stages = count_query(
        &conn,
        "SELECT COUNT(*) FROM crops c
         WHERE c.region = 'us' AND c.is_reference = 1
           AND NOT EXISTS (SELECT 1 FROM crop_stages cs WHERE cs.crop_id = c.id)",
    );
    assert_eq!(0, without_stages);
}
