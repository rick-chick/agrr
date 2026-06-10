//! Progress gateway parity with Rails (`DaemonClient#progress` args + normalized response).

use agrr_adapters_agrr::{normalize_progress_result, AgrrDaemonClient, FieldCultivationClimateAgrrGateway};
use agrr_domain::field_cultivation::gateways::FieldCultivationClimateProgressGateway;
use serde_json::json;

#[test]
fn normalize_maps_daily_progress_for_domain_mapper() {
    let payload = json!({
        "daily_progress": [
            { "date": "2026-03-01", "cumulative_gdd": 12.5, "stage_name": "育苗" }
        ]
    });
    let out = normalize_progress_result(&payload);
    assert_eq!(out["progress_records"][0]["stage_name"], "育苗");
}

#[test]
fn progress_daemon_args_match_rails_without_dummy_path() {
    // Avoid request-time connect retries when no daemon is expected in this test.
    std::env::set_var("AGRR_DAEMON_REQUEST_RETRIES", "1");
    let client = AgrrDaemonClient::new("/tmp/agrr_test_missing.sock");
    assert!(!client.daemon_running());
    let gateway = FieldCultivationClimateAgrrGateway::from_env();
    let crop = json!({
        "crop": { "crop_id": "1", "name": "x" },
        "stage_requirements": []
    });
    let weather = json!({ "data": [] });
    let result = gateway.calculate_progress(&crop, time::macros::date!(2026 - 01 - 01), &weather);
    assert!(result["progress_records"].as_array().unwrap().is_empty());
}
