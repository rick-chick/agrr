mod support;

use support::{apply_repair, count_query, TestDb};

#[test]
fn data_repair_jp_reference_crops_sets_cultivation_method_from_fixture() {
    let db = TestDb::new();
    let conn = db.conn();

    conn.execute(
        "INSERT INTO crops (name, variety, is_reference, user_id, region, groups, area_per_unit, revenue_per_area, created_at, updated_at)
         VALUES ('トマト', '大玉', 1, NULL, 'jp', '[\"Solanaceae\"]', 0.2, 1500.0, datetime('now'), datetime('now'));",
        [],
    )
    .unwrap();

    apply_repair(&db.paths, "jp", "repair_jp_reference_crops");

    let without_method = count_query(
        &conn,
        "SELECT COUNT(*) FROM crops
         WHERE region = 'jp' AND is_reference = 1 AND cultivation_method IS NULL",
    );
    assert_eq!(
        0,
        without_method,
        "every jp reference crop must have cultivation_method after repair"
    );

    let tomato_method: String = conn
        .query_row(
            "SELECT cultivation_method FROM crops
             WHERE region = 'jp' AND is_reference = 1 AND name = 'トマト' AND variety = '大玉'",
            [],
            |r| r.get(0),
        )
        .unwrap();
    assert_eq!("transplant", tomato_method);
}
