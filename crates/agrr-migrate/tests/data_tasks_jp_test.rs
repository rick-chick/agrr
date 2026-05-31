mod support;

use support::{apply_data, count_query, TestDb};

#[test]
fn data_apply_tasks_jp_inserts_reference_agricultural_tasks() {
    let db = TestDb::new();
    apply_data(&db.paths, "jp", "tasks");

    let conn = db.conn();
    let count = count_query(
        &conn,
        "SELECT COUNT(*) FROM agricultural_tasks WHERE region = 'jp' AND is_reference = 1",
    );
    assert_eq!(17, count, "jp TASK_DEFINITIONS has 17 tasks in extracted JSON");

    let name: String = conn
        .query_row(
            "SELECT name FROM agricultural_tasks WHERE region = 'jp' AND name = '耕耘' AND is_reference = 1",
            [],
            |r| r.get(0),
        )
        .unwrap();
    assert_eq!("耕耘", name);
}

#[test]
fn data_apply_tasks_us_and_in() {
    let db = TestDb::new();
    apply_data(&db.paths, "us", "tasks");
    apply_data(&db.paths, "in", "tasks");

    let conn = db.conn();
    let us = count_query(
        &conn,
        "SELECT COUNT(*) FROM agricultural_tasks WHERE region = 'us' AND is_reference = 1",
    );
    let india = count_query(
        &conn,
        "SELECT COUNT(*) FROM agricultural_tasks WHERE region = 'in' AND is_reference = 1",
    );
    assert!(us >= 10, "us reference tasks: {us}");
    assert!(india >= 10, "in reference tasks: {india}");
}
