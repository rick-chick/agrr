//! R4 HTTP smoke: co-located agrr-server stack + routing (not domain rules — see agrr-domain / E2E).

mod support;

use agrr_r4_contract::http::ContractClient;
use support::{
    developer_session_id, empty_headers, seed_masters_crop, seed_masters_crop_with_task_template,
    seed_work_record_plan, set_plan_task_schedule_sync_failed,
    set_plan_task_schedule_sync_failed_raw_error, clear_plan_task_schedules, status_and_body, user_id_for_session,
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
fn get_plans_authenticated_includes_farm_id() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let (status, body) = status_and_body(client.get("/api/v1/plans", Some(&session_id), &empty_headers()));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("plans list JSON");
    let plans = json.as_array().expect("plans array");
    let plan = plans
        .iter()
        .find(|p| p["id"].as_i64() == Some(seed.plan_id))
        .expect("seeded plan in list");
    assert_eq!(seed.farm_id, plan["farm_id"].as_i64().unwrap());
}

#[test]
fn get_work_hub_authenticated_returns_farm_rows_with_plan_id() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let (status, body) = status_and_body(client.get("/api/v1/work/hub", Some(&session_id), &empty_headers()));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("work hub JSON");
    let farms = json.as_array().expect("farms array");
    let farm = farms
        .iter()
        .find(|f| f["farm_id"].as_i64() == Some(seed.farm_id))
        .expect("seeded farm in hub list");
    assert_eq!(seed.plan_id, farm["plan_id"].as_i64().unwrap());
    assert!(farm["has_valid_fields"].as_bool().unwrap());
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
fn delete_work_records_unauthenticated_returns_401() {
    let client = ContractClient::from_env();
    let (status, body) = status_and_body(client.delete(
        "/api/v1/plans/1/work_records/1",
        None,
        &empty_headers(),
    ));
    assert_eq!(401, status, "{body}");
}

#[test]
fn delete_work_record_returns_deletion_undo_payload() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let (create_status, create_body) = status_and_body(client.post(
        &format!("/api/v1/plans/{}/work_records", seed.plan_id),
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "work_record": {
                "task_schedule_item_id": seed.task_schedule_item_id,
                "actual_date": "2026-06-12",
                "notes": "contract delete undo"
            }
        })),
    ));
    assert_eq!(201, create_status, "{create_body}");
    let create_json: serde_json::Value =
        serde_json::from_str(&create_body).expect("create work_record JSON");
    let record_id = create_json["work_record"]["id"]
        .as_i64()
        .expect("work_record id");

    let (delete_status, delete_body) = status_and_body(client.delete(
        &format!(
            "/api/v1/plans/{}/work_records/{}",
            seed.plan_id, record_id
        ),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, delete_status, "{delete_body}");
    let undo: serde_json::Value =
        serde_json::from_str(&delete_body).expect("delete work_record undo JSON");
    let undo_token = undo["undo_token"]
        .as_str()
        .expect("undo_token must be a non-empty string");
    assert!(!undo_token.is_empty(), "{delete_body}");
    assert_eq!(
        format!("/undo_deletion?undo_token={undo_token}"),
        undo["undo_path"].as_str().expect("undo_path")
    );
    assert!(
        undo["toast_message"].as_str().is_some_and(|m| !m.is_empty()),
        "{delete_body}"
    );
    assert!(undo.get("undo_deadline").is_some(), "{delete_body}");
    assert_eq!(5000, undo["auto_hide_after"].as_i64().unwrap(), "{delete_body}");
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

#[test]
fn get_task_schedule_includes_sync_state_and_items() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let (status, body) = status_and_body(client.get(
        &format!("/api/v1/plans/{}/task_schedule", seed.plan_id),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("task schedule JSON");
    let plan = &json["plan"];
    assert!(
        plan.get("task_schedule_sync_state").is_some(),
        "plan must include task_schedule_sync_state: {body}"
    );
    assert!(plan.get("task_schedule_sync_error").is_some());

    let fields = json["fields"].as_array().expect("fields array");
    assert!(!fields.is_empty(), "{body}");
    let general = fields[0]["schedules"]["general"]
        .as_array()
        .expect("general schedule bucket");
    assert!(
        !general.is_empty(),
        "completed plan seed must expose task schedule items: {body}"
    );
}

#[test]
fn get_task_schedule_normalizes_legacy_raw_sync_error_to_generic_i18n_key() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);
    set_plan_task_schedule_sync_failed_raw_error(seed.plan_id, "worker timeout");

    let (status, body) = status_and_body(client.get(
        &format!("/api/v1/plans/{}/task_schedule", seed.plan_id),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("task schedule JSON");
    let plan = &json["plan"];
    assert_eq!("failed", plan["task_schedule_sync_state"].as_str().unwrap());
    assert_eq!(
        "plans.task_schedules.sync_errors.generic",
        plan["task_schedule_sync_error"].as_str().unwrap()
    );
}

#[test]
fn get_task_schedule_exposes_sync_error_crop_id_for_missing_blueprints() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);
    set_plan_task_schedule_sync_failed(
        seed.plan_id,
        "plans.task_schedules.sync_errors.missing_crop_blueprints",
        Some(seed.crop_id),
    );

    let (status, body) = status_and_body(client.get(
        &format!("/api/v1/plans/{}/task_schedule", seed.plan_id),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("task schedule JSON");
    let plan = &json["plan"];
    assert_eq!("failed", plan["task_schedule_sync_state"].as_str().unwrap());
    assert_eq!(
        "plans.task_schedules.sync_errors.missing_crop_blueprints",
        plan["task_schedule_sync_error"].as_str().unwrap()
    );
    assert_eq!(seed.crop_id, plan["task_schedule_sync_error_crop_id"].as_i64().unwrap());
}

#[test]
fn get_task_schedule_includes_plan_crops_when_sync_failed_without_schedules() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);
    clear_plan_task_schedules(seed.plan_id);
    set_plan_task_schedule_sync_failed(
        seed.plan_id,
        "plans.task_schedules.sync_errors.generic",
        None,
    );

    let (status, body) = status_and_body(client.get(
        &format!("/api/v1/plans/{}/task_schedule", seed.plan_id),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("task schedule JSON");
    let fields = json["fields"].as_array().expect("fields array");
    assert!(
        !fields.is_empty(),
        "fields must include plan crops even when task_schedules are absent: {body}"
    );
    let field = &fields[0];
    assert_eq!(seed.crop_id, field["crop_id"].as_i64().unwrap());
    assert!(
        field["crop_name"].as_str().unwrap().contains("Contract Crop"),
        "crop_name must be present for banner remediation: {body}"
    );
    let remediation = json["plan"]["remediation_crops"]
        .as_array()
        .expect("remediation_crops");
    assert_eq!(1, remediation.len());
    assert_eq!(seed.crop_id, remediation[0]["crop_id"].as_i64().unwrap());
}

#[test]
fn post_task_schedule_regenerate_returns_generating() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let (status, body) = status_and_body(client.post(
        &format!("/api/v1/plans/{}/task_schedule/regenerate", seed.plan_id),
        Some(&session_id),
        &empty_headers(),
        None,
    ));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("regenerate JSON");
    assert_eq!(true, json["success"].as_bool().unwrap());
    assert_eq!("generating", json["task_schedule_sync_state"].as_str().unwrap());
}

#[test]
fn get_masters_crop_task_schedule_blueprints_unauthenticated_returns_401() {
    let client = ContractClient::from_env();
    let (status, body) = status_and_body(client.get(
        "/api/v1/masters/crops/1/task_schedule_blueprints",
        None,
        &empty_headers(),
    ));
    assert_eq!(401, status, "{body}");
}

#[test]
fn get_masters_crop_task_schedule_blueprints_authenticated_returns_array() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop(user_id);

    let (status, body) = status_and_body(client.get(
        &format!(
            "/api/v1/masters/crops/{}/task_schedule_blueprints",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("blueprints JSON");
    assert!(json.is_array(), "{body}");
}

#[test]
fn post_masters_crop_task_schedule_blueprints_regenerate_without_templates_returns_422() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop(user_id);

    let (status, body) = status_and_body(client.post(
        &format!(
            "/api/v1/masters/crops/{}/task_schedule_blueprints/regenerate",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
        None,
    ));
    assert_eq!(422, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("regenerate error JSON");
    assert_eq!(
        json.get("error_code").and_then(|v| v.as_str()),
        Some("missing_task_templates"),
        "{body}"
    );
    assert!(json.get("error").is_some(), "{body}");
}

#[test]
fn post_masters_crop_task_schedule_blueprints_create_without_template_returns_422() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop(user_id);
    let body = serde_json::json!({
        "agricultural_task_id": 999_999,
        "stage_order": 1,
        "stage_name": "Vegetative",
        "gdd_trigger": 100.0
    });

    let (status, body_text) = status_and_body(client.post(
        &format!(
            "/api/v1/masters/crops/{}/task_schedule_blueprints",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
        Some(body.clone()),
    ));
    assert_eq!(422, status, "{body_text}");
    let json: serde_json::Value = serde_json::from_str(&body_text).expect("create error JSON");
    assert_eq!(
        json.get("error_code").and_then(|v| v.as_str()),
        Some("task_template_not_registered"),
        "{body_text}"
    );
}

#[test]
fn post_masters_crop_task_schedule_blueprints_create_with_template_returns_201() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop_with_task_template(user_id);
    let body = serde_json::json!({
        "agricultural_task_id": seed.agricultural_task_id,
        "stage_order": 1,
        "stage_name": "Vegetative",
        "gdd_trigger": 120.0
    });

    let (status, body_text) = status_and_body(client.post(
        &format!(
            "/api/v1/masters/crops/{}/task_schedule_blueprints",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
        Some(body.clone()),
    ));
    assert_eq!(201, status, "{body_text}");
    let json: serde_json::Value = serde_json::from_str(&body_text).expect("create JSON");
    assert_eq!(seed.crop_id, json["crop_id"].as_i64().unwrap());
    assert_eq!(
        seed.agricultural_task_id,
        json["agricultural_task_id"].as_i64().unwrap()
    );
    assert_eq!("manual", json["source"].as_str().unwrap());
}
