mod support;

use support::{apply_data, count_query, TestDb};

#[test]
fn data_apply_jp_base_includes_admin_and_sample_fields() {
    std::env::set_var("AGRR_MIGRATE_SKIP_WEATHER", "1");
    let db = TestDb::new();
    apply_data(&db.paths, "jp", "base");

    let conn = db.conn();
    let users = count_query(&conn, "SELECT COUNT(*) FROM users");
    let admin = count_query(
        &conn,
        "SELECT COUNT(*) FROM users WHERE email = 'developer@agrr.dev' AND admin = 1",
    );
    let fields = count_query(&conn, "SELECT COUNT(*) FROM fields WHERE region = 'jp'");
    let anonymous = count_query(&conn, "SELECT COUNT(*) FROM users WHERE is_anonymous = 1");
    let farm_count = count_query(
        &conn,
        "SELECT COUNT(*) FROM farms WHERE is_reference = 1 AND region = 'jp'",
    );
    let n_farms = farm_count.min(5) as usize;
    let expected_fields: usize = (0..n_farms).map(|i| i % 2 + 2).sum();

    assert_eq!(2, users, "anonymous + developer");
    assert_eq!(1, admin);
    assert_eq!(1, anonymous);
    assert_eq!(expected_fields as i64, fields);
}
