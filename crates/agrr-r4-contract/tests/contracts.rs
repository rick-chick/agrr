//! R4 HTTP smoke: co-located agrr-server stack + routing (not domain rules — see agrr-domain / E2E).

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

#[test]
fn cable_route_is_not_global_api_not_migrated_501() {
    let client = ContractClient::from_env();
    let (status, body) = status_and_body(client.get("/cable", None, &empty_headers()));
    assert_ne!(
        501, status,
        "cable must be handled by agrr-server, not global 501 fallback: {body}"
    );
}
