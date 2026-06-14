//! R4 HTTP smoke: co-located agrr-server stack + routing (not domain rules — see agrr-domain / E2E).

mod support;

use agrr_r4_contract::http::ContractClient;
use support::{
    developer_session_id, empty_headers, seed_work_record_plan, status_and_body,
    user_id_for_session,
};

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

#[test]
fn post_work_records_unauthenticated_returns_401() {
    let client = ContractClient::from_env();
    let (status, body) = status_and_body(client.post(
        "/api/v1/plans/1/work_records",
        None,
        &empty_headers(),
        Some(serde_json::json!({
            "work_record": { "actual_date": "2026-06-12" }
        })),
    ));
    assert_eq!(401, status, "{body}");
}

#[test]
fn post_work_records_from_schedule_item_returns_201() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let (status, body) = status_and_body(client.post(
        &format!("/api/v1/plans/{}/work_records", seed.plan_id),
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "work_record": {
                "task_schedule_item_id": seed.task_schedule_item_id,
                "actual_date": "2026-06-12",
                "notes": "contract test"
            }
        })),
    ));
    assert_eq!(201, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("create work_record JSON");
    let record = &json["work_record"];
    assert_eq!(seed.plan_id, record["cultivation_plan_id"].as_i64().unwrap());
    assert_eq!(
        seed.task_schedule_item_id,
        record["task_schedule_item_id"].as_i64().unwrap()
    );
    assert_eq!("除草作業", record["name"].as_str().unwrap());
    assert_eq!("2026-06-12", record["actual_date"].as_str().unwrap());
    assert!(record["task_schedule_item"].is_object());
}

#[test]
fn post_work_records_ad_hoc_without_name_returns_422() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let (status, body) = status_and_body(client.post(
        &format!("/api/v1/plans/{}/work_records", seed.plan_id),
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "work_record": { "actual_date": "2026-06-12" }
        })),
    ));
    assert_eq!(422, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("validation JSON");
    let name_errors = json["errors"]["name"]
        .as_array()
        .expect("name validation errors");
    assert!(
        name_errors
            .iter()
            .any(|v| v.as_str() == Some(
                "activerecord.errors.models.work_record.attributes.name.blank"
            )),
        "{body}"
    );
}

#[test]
fn patch_task_schedule_item_skip_and_unskip_returns_item_payload() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);
    let skip_path = format!(
        "/api/v1/plans/{}/task_schedule/items/{}/skip",
        seed.plan_id, seed.task_schedule_item_id
    );
    let unskip_path = format!(
        "/api/v1/plans/{}/task_schedule/items/{}/unskip",
        seed.plan_id, seed.task_schedule_item_id
    );

    let (skip_status, skip_body) = status_and_body(
        client.patch(&skip_path, Some(&session_id), &empty_headers(), None),
    );
    assert_eq!(200, skip_status, "{skip_body}");
    let skip_json: serde_json::Value =
        serde_json::from_str(&skip_body).expect("skip task schedule item JSON");
    assert_eq!("skipped", skip_json["item"]["status"].as_str().unwrap());
    assert!(skip_json["item"]["cancelled_at"].is_string());

    let (unskip_status, unskip_body) = status_and_body(
        client.patch(&unskip_path, Some(&session_id), &empty_headers(), None),
    );
    assert_eq!(200, unskip_status, "{unskip_body}");
    let unskip_json: serde_json::Value =
        serde_json::from_str(&unskip_body).expect("unskip task schedule item JSON");
    assert_eq!("planned", unskip_json["item"]["status"].as_str().unwrap());
    assert!(unskip_json["item"]["cancelled_at"].is_null());
}
