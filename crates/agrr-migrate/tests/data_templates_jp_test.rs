mod support;

use support::{apply_data, count_query, use_jp_coords_weather_fixture, TestDb};

#[test]
fn data_apply_templates_jp_links_tasks_and_crops() {
    use_jp_coords_weather_fixture();
    let db = TestDb::new();
    apply_data(&db.paths, "jp", "base");
    apply_data(&db.paths, "jp", "tasks");
    apply_data(&db.paths, "jp", "templates");

    let conn = db.conn();
    let template_count = count_query(
        &conn,
        "SELECT COUNT(*) FROM crop_task_templates WHERE is_reference = 1",
    );
    assert!(
        template_count > 100,
        "expected many jp templates, got {template_count}"
    );

    let row: (String, String) = conn
        .query_row(
            "SELECT ctt.name, c.name FROM crop_task_templates ctt
             INNER JOIN crops c ON c.id = ctt.crop_id
             WHERE ctt.name = '耕耘' AND c.name = 'トマト' AND ctt.is_reference = 1
             LIMIT 1",
            [],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .expect("耕耘 x トマト template");
    assert_eq!("耕耘", row.0);
    assert_eq!("トマト", row.1);
}
