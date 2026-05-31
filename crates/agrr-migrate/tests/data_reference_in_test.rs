mod support;

use support::{apply_data, count_query, TestDb};

#[test]
fn data_apply_reference_data_in_region() {
    std::env::set_var("AGRR_MIGRATE_SKIP_WEATHER", "1");
    let db = TestDb::new();
    apply_data(&db.paths, "in", "base,nutrients,pests,tasks");

    let conn = db.conn();
    let farms = count_query(
        &conn,
        "SELECT COUNT(*) FROM farms WHERE region = 'in' AND is_reference = 1",
    );
    let crops = count_query(
        &conn,
        "SELECT COUNT(*) FROM crops WHERE region = 'in' AND is_reference = 1",
    );
    let pests = count_query(
        &conn,
        "SELECT COUNT(*) FROM pests WHERE region = 'in' AND is_reference = 1",
    );
    let tasks = count_query(
        &conn,
        "SELECT COUNT(*) FROM agricultural_tasks WHERE region = 'in' AND is_reference = 1",
    );

    assert!(farms >= 1, "in reference farms: {farms}");
    assert!(crops >= 10, "in reference crops: {crops}");
    assert_eq!(28, pests, "in extracted pests JSON has 28 entries");
    assert_eq!(17, tasks, "in extracted tasks JSON has 17 entries");

    // Rails create_basic_crops_without_ai_data has no crop_stages → nutrients migration seeds 0.
    let nutrients = count_query(
        &conn,
        "SELECT COUNT(*) FROM nutrient_requirements nr
         INNER JOIN crop_stages cs ON cs.id = nr.crop_stage_id
         INNER JOIN crops c ON c.id = cs.crop_id
         WHERE nr.is_reference = 1 AND c.is_reference = 1 AND c.region = 'in'",
    );
    assert_eq!(0, nutrients, "in inline crops have no stages; no nutrient rows");

    let crop_pests = count_query(
        &conn,
        "SELECT COUNT(*) FROM crop_pests cp
         INNER JOIN crops c ON c.id = cp.crop_id
         WHERE c.region = 'in'",
    );
    assert_eq!(3, crop_pests, "in archive pest crop links (name / name+variety resolve)");
}
