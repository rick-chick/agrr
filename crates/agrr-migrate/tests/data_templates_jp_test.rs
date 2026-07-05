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
    let blueprint_count = count_query(
        &conn,
        "SELECT COUNT(*) FROM crop_task_schedule_blueprints WHERE source = 'manual' AND stage_order IS NULL AND gdd_trigger IS NULL",
    );
    assert!(
        blueprint_count > 100,
        "expected many jp manual blueprints, got {blueprint_count}"
    );

    let row: (String, String) = conn
        .query_row(
            "SELECT b.name, c.name FROM crop_task_schedule_blueprints b
             INNER JOIN crops c ON c.id = b.crop_id
             WHERE b.name = '耕耘' AND c.name = 'トマト' AND b.source = 'manual'
             LIMIT 1",
            [],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .expect("耕耘 x トマト blueprint");
    assert_eq!("耕耘", row.0);
    assert_eq!("トマト", row.1);
}
