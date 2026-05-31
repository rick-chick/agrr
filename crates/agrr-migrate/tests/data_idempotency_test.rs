mod support;

use support::{apply_data, count_query, TestDb};

#[test]
fn data_apply_tasks_twice_is_idempotent() {
    let db = TestDb::new();
    apply_data(&db.paths, "jp", "tasks");
    let after_first = count_query(
        &db.conn(),
        "SELECT COUNT(*) FROM agricultural_tasks WHERE region = 'jp' AND is_reference = 1",
    );

    apply_data(&db.paths, "jp", "tasks");
    let after_second = count_query(
        &db.conn(),
        "SELECT COUNT(*) FROM agricultural_tasks WHERE region = 'jp' AND is_reference = 1",
    );

    assert_eq!(after_first, after_second);
    assert!(after_first > 0);
}
