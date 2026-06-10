mod support;

use support::{apply_repair, count_query, use_india_coords_weather_fixture, TestDb};

fn seed_india_punjab_stub(conn: &rusqlite::Connection) {
    conn.execute_batch(
        "INSERT INTO users (email, name, google_id, avatar_url, is_anonymous, admin, created_at, updated_at)
         SELECT 'anonymous@agrr.dev', 'Anonymous', NULL, NULL, 1, 0, datetime('now'), datetime('now')
         WHERE NOT EXISTS (SELECT 1 FROM users WHERE is_anonymous = 1);
         INSERT INTO farms (user_id, name, latitude, longitude, is_reference, region, weather_data_status,
           weather_data_fetched_years, weather_data_total_years, created_at, updated_at)
         SELECT u.id, 'Punjab', 30.9010, 75.8573, 1, 'in', 'pending', 0, 0, datetime('now'), datetime('now')
         FROM users u WHERE u.is_anonymous = 1 LIMIT 1;",
    )
    .unwrap();
}

#[test]
fn data_repair_india_reference_farms_restores_fixture_farms() {
    use_india_coords_weather_fixture();
    let db = TestDb::new();
    let conn = db.conn();
    seed_india_punjab_stub(&conn);

    let before = count_query(
        &conn,
        "SELECT COUNT(*) FROM farms WHERE region = 'in' AND is_reference = 1",
    );
    assert_eq!(1, before);
    assert_eq!(
        1,
        count_query(
            &conn,
            "SELECT COUNT(*) FROM farms WHERE region = 'in' AND is_reference = 1 AND name = 'Punjab'",
        )
    );

    apply_repair(&db.paths, "in", "repair_india_reference_farms");

    let farms = count_query(
        &conn,
        "SELECT COUNT(*) FROM farms WHERE region = 'in' AND is_reference = 1",
    );
    assert_eq!(
        50, farms,
        "repair should upsert all farms from india_reference_weather.json"
    );
    assert_eq!(
        0,
        count_query(
            &conn,
            "SELECT COUNT(*) FROM farms WHERE region = 'in' AND is_reference = 1 AND name = 'Punjab'",
        ),
        "legacy stub farm name must be removed"
    );
}

#[test]
fn data_repair_india_reference_farms_is_idempotent() {
    use_india_coords_weather_fixture();
    let db = TestDb::new();
    seed_india_punjab_stub(&db.conn());

    apply_repair(&db.paths, "in", "repair_india_reference_farms");
    apply_repair(&db.paths, "in", "repair_india_reference_farms");

    let conn = db.conn();
    let farms = count_query(
        &conn,
        "SELECT COUNT(*) FROM farms WHERE region = 'in' AND is_reference = 1",
    );
    assert_eq!(50, farms);
}
