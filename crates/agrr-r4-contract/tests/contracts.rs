//! R4 HTTP contracts (P8.6 — migrate from `test/contract/*_contract_test.rb`).

use agrr_r4_contract::http::ContractClient;
use std::collections::HashMap;

fn empty_headers() -> HashMap<String, String> {
    HashMap::new()
}

fn status_and_body(response: reqwest::blocking::Response) -> (u16, String) {
    let status = response.status().as_u16();
    let body = response.text().expect("response body");
    (status, body)
}

// Parity: test/contract/api_v1_health_contract_test.rb
#[test]
fn get_api_v1_health_returns_ok_payload() {
    let client = ContractClient::from_env();
    let (status, body) = status_and_body(client.get("/api/v1/health", None, &empty_headers()));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("health JSON");
    assert_eq!("ok", json["status"].as_str().unwrap());
    assert_eq!("sqlite3", json["database"].as_str().unwrap());
    assert!(json["timestamp"].as_str().is_some());
    assert!(json["version"].as_str().is_some());
}

// Parity: test/contract/optimization_channel_rust_contract_test.rb
#[test]
fn cable_route_is_not_global_api_not_migrated_501() {
    let client = ContractClient::from_env();
    let (status, body) = status_and_body(client.get("/cable", None, &empty_headers()));
    assert_ne!(
        501, status,
        "cable must be handled by agrr-server, not global 501 fallback: {body}"
    );
}

// Parity: test/contract/ai_api_contract_test.rb — route wired on agrr-server (not 501)
#[test]
fn crops_ai_create_is_not_501() {
    let client = ContractClient::from_env();
    let (status, body) = status_and_body(
        client.post(
            "/api/v1/crops/ai_create",
            None,
            &empty_headers(),
            Some(serde_json::json!({})),
        ),
    );
    assert_ne!(501, status, "{body}");
    assert!(
        [400, 401, 422, 503].contains(&status),
        "unexpected status {status}: {body}"
    );
}

#[test]
fn fertilizes_ai_create_is_not_501() {
    let client = ContractClient::from_env();
    let (status, body) = status_and_body(
        client.post(
            "/api/v1/fertilizes/ai_create",
            None,
            &empty_headers(),
            Some(serde_json::json!({})),
        ),
    );
    assert_ne!(501, status, "{body}");
    assert!(
        [400, 401, 422, 503].contains(&status),
        "unexpected status {status}: {body}"
    );
}

#[test]
fn pests_ai_create_is_not_501() {
    let client = ContractClient::from_env();
    let (status, body) = status_and_body(
        client.post(
            "/api/v1/pests/ai_create",
            None,
            &empty_headers(),
            Some(serde_json::json!({})),
        ),
    );
    assert_ne!(501, status, "{body}");
    assert!(
        [400, 401, 422, 503].contains(&status),
        "unexpected status {status}: {body}"
    );
}

#[test]
fn pests_ai_update_is_not_501() {
    let client = ContractClient::from_env();
    let (status, body) = status_and_body(
        client.post(
            "/api/v1/pests/1/ai_update",
            None,
            &empty_headers(),
            Some(serde_json::json!({})),
        ),
    );
    assert_ne!(501, status, "{body}");
    assert!(
        [400, 401, 404, 422, 503].contains(&status),
        "unexpected status {status}: {body}"
    );
}
