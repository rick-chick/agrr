//! Progress gateway parity with Rails (`DaemonClient#progress` args + normalized response).

mod common;

use agrr_adapters_agrr::FieldCultivationClimateAgrrGateway;
use agrr_domain::field_cultivation::gateways::FieldCultivationClimateProgressGateway;
use serde_json::json;

#[test]
fn calculate_progress_result_reports_not_running() {
    common::with_daemon_env("1", "/tmp/agrr_test_calculate_progress_result_missing.sock", || {
        let gateway = FieldCultivationClimateAgrrGateway::from_env();
        let crop = json!({
            "crop": { "crop_id": "1", "name": "x" },
            "stage_requirements": []
        });
        let weather = json!({ "data": [] });
        let err = gateway
            .calculate_progress_result(&crop, time::macros::date!(2026 - 01 - 01), &weather)
            .expect_err("daemon not running");
        assert!(matches!(err, agrr_adapters_agrr::AgrrDaemonError::NotRunning(_)));
    });
}

#[test]
fn calculate_progress_trait_reports_not_running() {
    common::with_daemon_env("1", "/tmp/agrr_test_calculate_progress_trait_missing.sock", || {
        let gateway = FieldCultivationClimateAgrrGateway::from_env();
        let crop = json!({
            "crop": { "crop_id": "1", "name": "x" },
            "stage_requirements": []
        });
        let weather = json!({ "data": [] });
        let err = gateway
            .calculate_progress(&crop, time::macros::date!(2026 - 01 - 01), &weather)
            .expect_err("daemon not running");
        assert!(err.to_string().contains("not running"));
    });
}

#[test]
#[ignore = "manual: requires agrr daemon socket and debug fixtures in container"]
fn live_daemon_progress_returns_records_from_debug_fixtures() {
    use std::fs;

    let crop_path = std::env::var("PROGRESS_CROP_FILE")
        .unwrap_or_else(|_| "/app/tmp/debug/progress_crop_1783246182.json".into());
    let weather_path = std::env::var("PROGRESS_WEATHER_FILE")
        .unwrap_or_else(|_| "/app/tmp/debug/progress_weather_1783246182.json".into());
    let start_date = time::macros::date!(2026 - 05 - 24);

    let crop: serde_json::Value =
        serde_json::from_str(&fs::read_to_string(&crop_path).expect("crop file")).expect("crop json");
    let weather: serde_json::Value =
        serde_json::from_str(&fs::read_to_string(&weather_path).expect("weather file"))
            .expect("weather json");

    let gateway = FieldCultivationClimateAgrrGateway::from_env();
    let result = gateway
        .calculate_progress(&crop, start_date, &weather)
        .expect("live daemon progress");
    let count = result["progress_records"]
        .as_array()
        .map(|a| a.len())
        .unwrap_or(0);
    assert!(count > 0, "expected progress_records, got {result}");
}
