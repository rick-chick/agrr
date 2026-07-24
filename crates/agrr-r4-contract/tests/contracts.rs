//! R4 HTTP smoke: co-located agrr-server stack + routing (not domain rules — see agrr-domain / E2E).

mod support;

use agrr_r4_contract::http::ContractClient;
use support::{
    agrr_regeneration_contract_available, assert_builtin_generation_deprecated_headers,
    assert_crop_task_template_api_removed,
    clear_plan_task_schedules, developer_session_id, empty_headers, farmer_session_id,
    researcher_session_id,
    find_schedule_item, poll_task_schedule_sync_ready, schedule_item_ids_from_response,
    seed_masters_crop, seed_masters_crop_with_manual_blueprint, seed_masters_crop_with_stages,
    seed_masters_crop_with_stages_and_blueprints, seed_reference_crop_with_stage,
    seed_task_schedule_regeneration_plan,
    seed_work_record_plan, set_plan_task_schedule_sync_failed,
    set_plan_task_schedule_sync_failed_raw_error, status_and_body,
    upload_ready_work_record_photo, user_id_for_session,
    seed_farm_temperature_chart_completed, seed_farm_temperature_chart_fetching,
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
    assert_eq!("F1", record["field_name"].as_str().unwrap());
    assert_eq!(seed.crop_name, record["crop_name"].as_str().unwrap());
    assert!(record["task_schedule_item"].is_object());
}

#[test]
fn get_work_records_list_includes_field_and_crop_name() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let create_path = format!("/api/v1/plans/{}/work_records", seed.plan_id);
    let (create_status, create_body) = status_and_body(client.post(
        &create_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "work_record": {
                "task_schedule_item_id": seed.task_schedule_item_id,
                "actual_date": "2026-06-12",
                "notes": "list contract test"
            }
        })),
    ));
    assert_eq!(201, create_status, "{create_body}");
    let create_json: serde_json::Value =
        serde_json::from_str(&create_body).expect("create work_record JSON");
    let record_id = create_json["work_record"]["id"].as_i64().expect("record id");

    let list_path = format!("/api/v1/plans/{}/work_records", seed.plan_id);
    let (list_status, list_body) = status_and_body(
        client.get(&list_path, Some(&session_id), &empty_headers()),
    );
    assert_eq!(200, list_status, "{list_body}");
    let list_json: serde_json::Value =
        serde_json::from_str(&list_body).expect("work_records list JSON");
    let records = list_json["work_records"].as_array().expect("work_records");
    let record = records
        .iter()
        .find(|r| r["id"].as_i64() == Some(record_id))
        .expect("created record in list");
    assert_eq!("F1", record["field_name"].as_str().unwrap());
    assert_eq!(seed.crop_name, record["crop_name"].as_str().unwrap());
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
fn work_record_photo_upload_init_complete_and_list() {
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
                "notes": "contract photo"
            }
        })),
    ));
    assert_eq!(201, create_status, "{create_body}");
    let create_json: serde_json::Value =
        serde_json::from_str(&create_body).expect("create work_record JSON");
    let record_id = create_json["work_record"]["id"]
        .as_i64()
        .expect("work_record id");

    let init_path = format!(
        "/api/v1/plans/{}/work_records/{}/photos/upload_init",
        seed.plan_id, record_id
    );
    let (init_status, init_body) = status_and_body(client.post(
        &init_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "photo": { "content_type": "image/jpeg" }
        })),
    ));
    assert_eq!(201, init_status, "{init_body}");
    let init_json: serde_json::Value =
        serde_json::from_str(&init_body).expect("upload_init JSON");
    let photo_id = init_json["photo"]["id"].as_i64().expect("photo id");
    let upload_url = init_json["photo"]["upload_url"]
        .as_str()
        .expect("upload_url");

    let jpeg_bytes: Vec<u8> = vec![0xFF, 0xD8, 0xFF, 0xD9];
    let (upload_status, upload_body) = status_and_body(client.put_bytes(
        upload_url,
        Some(&session_id),
        &empty_headers(),
        "image/jpeg",
        &jpeg_bytes,
    ));
    assert_eq!(204, upload_status, "{upload_body}");

    let complete_path = format!(
        "/api/v1/plans/{}/work_records/{}/photos/{}/upload_complete",
        seed.plan_id, record_id, photo_id
    );
    let (complete_status, complete_body) = status_and_body(client.post(
        &complete_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "photo": { "byte_size": jpeg_bytes.len() }
        })),
    ));
    assert_eq!(200, complete_status, "{complete_body}");
    let complete_json: serde_json::Value =
        serde_json::from_str(&complete_body).expect("upload_complete JSON");
    assert_eq!(photo_id, complete_json["photo"]["id"].as_i64().unwrap());
    assert_eq!(0, complete_json["photo"]["position"].as_i64().unwrap());

    let list_path = format!("/api/v1/plans/{}/work_records", seed.plan_id);
    let (list_status, list_body) = status_and_body(
        client.get(&list_path, Some(&session_id), &empty_headers()),
    );
    assert_eq!(200, list_status, "{list_body}");
    let list_json: serde_json::Value =
        serde_json::from_str(&list_body).expect("work_records list JSON");
    let records = list_json["work_records"].as_array().expect("work_records");
    let record = records
        .iter()
        .find(|r| r["id"].as_i64() == Some(record_id))
        .expect("record in list");
    let photos = record["photos"].as_array().expect("photos array");
    assert_eq!(1, photos.len());
    assert_eq!(photo_id, photos[0]["id"].as_i64().unwrap());

    let content_url = photos[0]["url"].as_str().expect("photo url");
    let (content_status, _) = status_and_body(
        client.get(content_url, Some(&session_id), &empty_headers()),
    );
    assert_eq!(200, content_status);
}

#[test]
fn work_record_photo_upload_init_rejects_when_at_limit() {
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
                "notes": "photo limit contract"
            }
        })),
    ));
    assert_eq!(201, create_status, "{create_body}");
    let create_json: serde_json::Value =
        serde_json::from_str(&create_body).expect("create work_record JSON");
    let record_id = create_json["work_record"]["id"]
        .as_i64()
        .expect("work_record id");

    for _ in 0..3 {
        upload_ready_work_record_photo(&client, &session_id, seed.plan_id, record_id);
    }

    let init_path = format!(
        "/api/v1/plans/{}/work_records/{}/photos/upload_init",
        seed.plan_id, record_id
    );
    let (init_status, init_body) = status_and_body(client.post(
        &init_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "photo": { "content_type": "image/jpeg" }
        })),
    ));
    assert_eq!(422, init_status, "{init_body}");
    let init_json: serde_json::Value =
        serde_json::from_str(&init_body).expect("upload_init rejection JSON");
    let photos_errors = init_json["errors"]["photos"]
        .as_array()
        .expect("photos errors array");
    assert!(
        photos_errors
            .iter()
            .any(|msg| {
                msg.as_str()
                    == Some("plans.work_records.photos.errors.limit_exceeded")
            }),
        "{init_body}"
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
fn get_task_schedule_includes_compat_milestones_labels_and_week_days() {
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
    assert!(
        json["milestones"].as_array().is_some(),
        "milestones array required for API compat: {body}"
    );
    assert!(
        json["labels"].is_object(),
        "labels object required for API compat: {body}"
    );
    let days = json["week"]["days"]
        .as_array()
        .expect("week.days array required for API compat");
    assert_eq!(7, days.len(), "{body}");
    assert!(days[0]["date"].as_str().is_some());
    assert!(days[0]["weekday"].as_str().is_some());
    assert!(days[0]["is_today"].is_boolean());
}

#[test]
fn get_task_schedule_scope_plan_includes_scheduled_items_and_cultivation_period() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let path = std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH");
    let conn = rusqlite::Connection::open(&path).expect("open sqlite");
    conn.execute(
        "UPDATE field_cultivations SET start_date = '2026-05-01', completion_date = '2026-09-30' \
         WHERE cultivation_plan_id = ?1",
        rusqlite::params![seed.plan_id],
    )
    .expect("set cultivation period");

    let (status, body) = status_and_body(client.get(
        &format!(
            "/api/v1/plans/{}/task_schedule?scope=plan&week_start=2026-07-05",
            seed.plan_id
        ),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("task schedule JSON");
    let fields = json["fields"].as_array().expect("fields array");
    assert_eq!(1, fields.len(), "{body}");
    assert_eq!("2026-05-01", fields[0]["cultivation_start_date"].as_str().unwrap());
    assert_eq!("2026-09-30", fields[0]["cultivation_end_date"].as_str().unwrap());
    let general = fields[0]["schedules"]["general"]
        .as_array()
        .expect("general schedule bucket");
    assert!(
        !general.is_empty(),
        "plan scope must include items outside the requested week: {body}"
    );
}

#[test]
fn get_task_schedule_scope_week_filters_to_requested_week() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let (status, body) = status_and_body(client.get(
        &format!(
            "/api/v1/plans/{}/task_schedule?scope=week&week_start=2026-06-01",
            seed.plan_id
        ),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("task schedule JSON");
    let fields = json["fields"].as_array().expect("fields array");
    assert_eq!(1, fields.len(), "{body}");
    let general = fields[0]["schedules"]["general"]
        .as_array()
        .expect("general schedule bucket");
    assert_eq!(1, general.len(), "{body}");
    assert_eq!("2026-06-02", general[0]["scheduled_date"].as_str().unwrap());

    let (far_status, far_body) = status_and_body(client.get(
        &format!(
            "/api/v1/plans/{}/task_schedule?scope=week&week_start=2026-12-01",
            seed.plan_id
        ),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, far_status, "{far_body}");
    let far_json: serde_json::Value =
        serde_json::from_str(&far_body).expect("task schedule JSON (far week)");
    let far_fields = far_json["fields"].as_array().expect("fields array");
    assert!(
        far_fields.is_empty(),
        "week scope must hide fields with only out-of-week schedules: {far_body}"
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
fn post_task_schedule_regenerate_preserves_completed_and_manual_items() {
    if !agrr_regeneration_contract_available() {
        eprintln!("skip: agrr binary unavailable for regeneration contract test");
        return;
    }
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_task_schedule_regeneration_plan(user_id);

    let json = poll_task_schedule_sync_ready(&client, &session_id, seed.plan_id);
    let item_ids = schedule_item_ids_from_response(&json);

    assert!(
        item_ids.contains(&seed.manual_item_id),
        "manual item must survive regeneration: {json}"
    );
    assert!(
        item_ids.contains(&seed.completed_item_id),
        "completed item must survive regeneration: {json}"
    );
    assert!(
        !item_ids.contains(&seed.agrr_item_id),
        "uncompleted agrr item must be replaced: {json}"
    );

    let completed = find_schedule_item(&json, seed.completed_item_id);
    assert_eq!(true, completed["completed"].as_bool().unwrap());
}

#[test]
fn post_task_schedule_regenerate_avoids_duplicate_for_preserved_match_key() {
    if !agrr_regeneration_contract_available() {
        eprintln!("skip: agrr binary unavailable for regeneration contract test");
        return;
    }
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_task_schedule_regeneration_plan(user_id);

    let json = poll_task_schedule_sync_ready(&client, &session_id, seed.plan_id);
    let general_items = json["fields"][0]["schedules"]["general"]
        .as_array()
        .expect("general schedules");
    let matching: Vec<_> = general_items
        .iter()
        .filter(|item| {
            item["agricultural_task_id"].as_i64() == Some(seed.agricultural_task_id)
                && item["stage_order"].as_i64() == Some(1)
        })
        .collect();
    assert_eq!(
        1,
        matching.len(),
        "preserved + regenerated items must not duplicate match key: {json}"
    );
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
fn post_masters_crop_task_schedule_blueprints_regenerate_without_blueprints_returns_422() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop(user_id);

    let response = client.post(
        &format!(
            "/api/v1/masters/crops/{}/task_schedule_blueprints/regenerate",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
        None,
    );
    let headers = response.headers().clone();
    let (status, body) = status_and_body(response);
    assert_eq!(422, status, "{body}");
    assert_builtin_generation_deprecated_headers(&headers, &body, "setup_proposal");
    let json: serde_json::Value = serde_json::from_str(&body).expect("regenerate error JSON");
    assert_eq!(
        json.get("error_code").and_then(|v| v.as_str()),
        Some("missing_blueprints"),
        "{body}"
    );
    assert!(json.get("error").is_some(), "{body}");
}

#[test]
fn post_masters_crop_task_schedule_blueprints_create_without_agricultural_task_returns_422() {
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
        Some("agricultural_task_not_found"),
        "{body_text}"
    );
}

#[test]
fn post_masters_crop_task_schedule_blueprints_create_with_manual_blueprint_returns_201() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop_with_manual_blueprint(user_id);
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
    let task_name = json["name"]
        .as_str()
        .or_else(|| json["agricultural_task"]["name"].as_str());
    assert!(
        task_name.is_some() && !task_name.unwrap().is_empty(),
        "blueprint must expose agricultural task name: {body_text}"
    );
}

#[test]
fn get_masters_crop_agricultural_tasks_returns_410_gone() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop(user_id);

    let (status, body) = status_and_body(client.get(
        &format!(
            "/api/v1/masters/crops/{}/agricultural_tasks",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_crop_task_template_api_removed(status, &body);
}

#[test]
fn post_masters_crop_agricultural_tasks_returns_410_gone() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop(user_id);

    let (status, body) = status_and_body(client.post(
        &format!(
            "/api/v1/masters/crops/{}/agricultural_tasks",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({ "name": "obsolete" })),
    ));
    assert_crop_task_template_api_removed(status, &body);
}

#[test]
fn put_masters_crop_agricultural_tasks_returns_410_gone() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop(user_id);

    let (status, body) = status_and_body(client.put(
        &format!(
            "/api/v1/masters/crops/{}/agricultural_tasks/1",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({ "name": "obsolete" })),
    ));
    assert_crop_task_template_api_removed(status, &body);
}

#[test]
fn patch_masters_crop_agricultural_tasks_returns_410_gone() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop(user_id);

    let (status, body) = status_and_body(client.patch(
        &format!(
            "/api/v1/masters/crops/{}/agricultural_tasks/1",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({ "name": "obsolete" })),
    ));
    assert_crop_task_template_api_removed(status, &body);
}

#[test]
fn delete_masters_crop_agricultural_tasks_returns_410_gone() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop(user_id);

    let (status, body) = status_and_body(client.delete(
        &format!(
            "/api/v1/masters/crops/{}/agricultural_tasks/1",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_crop_task_template_api_removed(status, &body);
}

#[test]
fn post_reference_crop_stage_by_non_admin_returns_404() {
    let client = ContractClient::from_env();
    let session_id = farmer_session_id(&client);
    let seed = seed_reference_crop_with_stage();

    let (status, body) = status_and_body(client.post(
        &format!("/api/v1/masters/crops/{}/crop_stages", seed.crop_id),
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "crop_stage": { "name": "Forbidden Stage", "order": 2 }
        })),
    ));
    assert_eq!(404, status, "{body}");
}

#[test]
fn patch_reference_crop_stage_by_non_admin_returns_404() {
    let client = ContractClient::from_env();
    let session_id = farmer_session_id(&client);
    let seed = seed_reference_crop_with_stage();

    let (status, body) = status_and_body(client.patch(
        &format!(
            "/api/v1/masters/crops/{}/crop_stages/{}",
            seed.crop_id, seed.stage_id
        ),
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({ "crop_stage": { "name": "Renamed" } })),
    ));
    assert_eq!(404, status, "{body}");
}

#[test]
fn patch_reference_crop_thermal_requirement_by_non_admin_returns_404() {
    let client = ContractClient::from_env();
    let session_id = farmer_session_id(&client);
    let seed = seed_reference_crop_with_stage();

    let (status, body) = status_and_body(client.patch(
        &format!(
            "/api/v1/masters/crops/{}/crop_stages/{}/thermal_requirement",
            seed.crop_id, seed.stage_id
        ),
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "thermal_requirement": { "required_gdd": "100" }
        })),
    ));
    assert_eq!(404, status, "{body}");
}

#[test]
fn post_reference_crop_stage_by_admin_succeeds() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let seed = seed_reference_crop_with_stage();

    let (status, body) = status_and_body(client.post(
        &format!("/api/v1/masters/crops/{}/crop_stages", seed.crop_id),
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "crop_stage": { "name": "Admin Stage", "order": 2 }
        })),
    ));
    assert_eq!(201, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("stage JSON");
    assert_eq!("Admin Stage", json["name"].as_str().unwrap());
}

#[test]
fn put_masters_crop_stages_reorder_swaps_stage_orders() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop_with_stages(user_id, 2);
    let [stage_a, stage_b] = seed.stage_ids.as_slice() else {
        panic!("expected two crop stages");
    };

    let (status, body) = status_and_body(client.put(
        &format!(
            "/api/v1/masters/crops/{}/crop_stages/reorder",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "crop_stages": [
                { "id": stage_a, "order": 2 },
                { "id": stage_b, "order": 1 }
            ]
        })),
    ));
    assert_eq!(200, status, "{body}");
    let json: Vec<serde_json::Value> = serde_json::from_str(&body).expect("reorder JSON");
    let orders: Vec<i64> = json
        .iter()
        .map(|stage| stage["order"].as_i64().expect("order"))
        .collect();
    assert_eq!(orders, vec![1, 2]);
    let names: Vec<&str> = json
        .iter()
        .map(|stage| stage["name"].as_str().expect("name"))
        .collect();
    assert_eq!(names, vec!["Stage 2", "Stage 1"]);
}

#[test]
fn post_masters_crop_stage_conflicting_order_returns_422() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop_with_stages(user_id, 1);

    let (status, body) = status_and_body(client.post(
        &format!("/api/v1/masters/crops/{}/crop_stages", seed.crop_id),
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "crop_stage": { "name": "Duplicate Order Stage", "order": 1 }
        })),
    ));
    assert_eq!(422, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("error JSON");
    assert!(json.get("errors").is_some(), "{body}");
}

#[test]
fn patch_masters_crop_stage_conflicting_order_returns_422() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop_with_stages(user_id, 2);
    let [stage_a, _stage_b] = seed.stage_ids.as_slice() else {
        panic!("expected two crop stages");
    };

    let (status, body) = status_and_body(client.patch(
        &format!(
            "/api/v1/masters/crops/{}/crop_stages/{}",
            seed.crop_id, stage_a
        ),
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({ "crop_stage": { "order": 2 } })),
    ));
    assert_eq!(422, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("error JSON");
    assert!(json.get("errors").is_some(), "{body}");
}

#[test]
fn put_masters_crop_stages_reorder_remaps_blueprint_stage_orders() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop_with_stages_and_blueprints(user_id);
    let [stage_a, stage_b] = seed.stage_ids.as_slice() else {
        panic!("expected two crop stages");
    };
    let [blueprint_a, blueprint_b] = seed.blueprint_ids.as_slice() else {
        panic!("expected two blueprints");
    };

    let (status, body) = status_and_body(client.put(
        &format!(
            "/api/v1/masters/crops/{}/crop_stages/reorder",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "crop_stages": [
                { "id": stage_a, "order": 2 },
                { "id": stage_b, "order": 1 }
            ]
        })),
    ));
    assert_eq!(200, status, "{body}");

    let (status, body) = status_and_body(client.get(
        &format!(
            "/api/v1/masters/crops/{}/task_schedule_blueprints",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, status, "{body}");
    let json: Vec<serde_json::Value> = serde_json::from_str(&body).expect("blueprints JSON");
    let stage_order_for = |blueprint_id: i64| {
        json.iter()
            .find(|item| item["id"].as_i64() == Some(blueprint_id))
            .and_then(|item| item["stage_order"].as_i64())
    };
    assert_eq!(stage_order_for(*blueprint_a), Some(2));
    assert_eq!(stage_order_for(*blueprint_b), Some(1));
}

#[test]
fn delete_masters_crop_stage_unassigns_linked_blueprints() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop_with_stages_and_blueprints(user_id);
    let [stage_a, _stage_b] = seed.stage_ids.as_slice() else {
        panic!("expected two crop stages");
    };
    let [blueprint_a, _blueprint_b] = seed.blueprint_ids.as_slice() else {
        panic!("expected two blueprints");
    };

    let (status, body) = status_and_body(client.delete(
        &format!(
            "/api/v1/masters/crops/{}/crop_stages/{}",
            seed.crop_id, stage_a
        ),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(204, status, "{body}");

    let (status, body) = status_and_body(client.get(
        &format!(
            "/api/v1/masters/crops/{}/task_schedule_blueprints",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, status, "{body}");
    let json: Vec<serde_json::Value> = serde_json::from_str(&body).expect("blueprints JSON");
    let deleted_stage_blueprint = json
        .iter()
        .find(|item| item["id"].as_i64() == Some(*blueprint_a))
        .expect("blueprint for deleted stage");
    assert!(deleted_stage_blueprint["stage_order"].is_null());
    assert!(deleted_stage_blueprint["stage_name"].is_null());
}

#[test]
fn get_masters_crop_stage_wrong_crop_returns_404() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let crop_a = seed_masters_crop_with_stages(user_id, 1);
    let crop_b = seed_masters_crop_with_stages(user_id, 1);
    let [stage_of_b] = crop_b.stage_ids.as_slice() else {
        panic!("expected one crop stage");
    };

    let (status, body) = status_and_body(client.get(
        &format!(
            "/api/v1/masters/crops/{}/crop_stages/{}",
            crop_a.crop_id, stage_of_b
        ),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(404, status, "{body}");
}

#[test]
fn patch_masters_crop_stage_wrong_crop_returns_404_and_does_not_mutate_stage() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let crop_a = seed_masters_crop_with_stages(user_id, 1);
    let crop_b = seed_masters_crop_with_stages(user_id, 1);
    let [stage_of_b] = crop_b.stage_ids.as_slice() else {
        panic!("expected one crop stage");
    };

    let (status, body) = status_and_body(client.patch(
        &format!(
            "/api/v1/masters/crops/{}/crop_stages/{}",
            crop_a.crop_id, stage_of_b
        ),
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({ "crop_stage": { "name": "Hacked Stage Name" } })),
    ));
    assert_eq!(404, status, "{body}");

    let (status, body) = status_and_body(client.get(
        &format!(
            "/api/v1/masters/crops/{}/crop_stages/{}",
            crop_b.crop_id, stage_of_b
        ),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("stage JSON");
    assert_eq!("Stage 1", json["name"].as_str().unwrap());
}

#[test]
fn delete_masters_crop_stage_wrong_crop_returns_404() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let crop_a = seed_masters_crop_with_stages(user_id, 1);
    let crop_b = seed_masters_crop_with_stages(user_id, 1);
    let [stage_of_b] = crop_b.stage_ids.as_slice() else {
        panic!("expected one crop stage");
    };

    let (status, body) = status_and_body(client.delete(
        &format!(
            "/api/v1/masters/crops/{}/crop_stages/{}",
            crop_a.crop_id, stage_of_b
        ),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(404, status, "{body}");
}

#[test]
fn get_masters_crop_stage_temperature_requirement_wrong_crop_returns_404() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let crop_a = seed_masters_crop_with_stages(user_id, 1);
    let crop_b = seed_masters_crop_with_stages(user_id, 1);
    let [stage_of_b] = crop_b.stage_ids.as_slice() else {
        panic!("expected one crop stage");
    };

    let path = std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH");
    let conn = rusqlite::Connection::open(&path).expect("open contract sqlite");
    conn.execute(
        "INSERT INTO temperature_requirements (crop_stage_id, base_temperature, optimal_min, optimal_max, max_temperature, created_at, updated_at)
         VALUES (?1, 10.0, 18.0, 28.0, 35.0, datetime('now'), datetime('now'))",
        rusqlite::params![stage_of_b],
    )
    .expect("insert temperature requirement");

    let (status, body) = status_and_body(client.get(
        &format!(
            "/api/v1/masters/crops/{}/crop_stages/{}/temperature_requirement",
            crop_a.crop_id, stage_of_b
        ),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(404, status, "{body}");
}

fn valid_setup_proposal_body() -> serde_json::Value {
    serde_json::json!({
        "stages": [{
            "name": "育苗",
            "order": 1,
            "thermal_requirement": { "required_gdd": "120" }
        }],
        "agricultural_tasks": [{
            "ref": "task-weeding",
            "name": "除草",
            "task_type": "field_work",
            "region": "jp"
        }],
        "task_schedule_blueprints": [{
            "agricultural_task_ref": "task-weeding",
            "stage_order": 1,
            "stage_name": "育苗",
            "gdd_trigger": 0,
            "task_type": "field_work",
            "priority": 1
        }]
    })
}

#[test]
fn post_masters_crop_setup_proposal_dry_run_invalid_returns_errors() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop(user_id);
    let mut body = valid_setup_proposal_body();
    body["stages"][0]["thermal_requirement"] = serde_json::json!({});

    let (status, response_body) = status_and_body(client.post(
        &format!(
            "/api/v1/masters/crops/{}/setup_proposal?mode=dry_run",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
        Some(body),
    ));
    assert_eq!(200, status, "{response_body}");
    let json: serde_json::Value = serde_json::from_str(&response_body).expect("dry_run JSON");
    assert_eq!(false, json["valid"].as_bool().unwrap());
    assert!(json["errors"].as_array().unwrap().len() > 0, "{response_body}");
}

#[test]
fn post_masters_crop_setup_proposal_dry_run_valid_returns_normalized() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop(user_id);

    let (status, response_body) = status_and_body(client.post(
        &format!(
            "/api/v1/masters/crops/{}/setup_proposal?mode=dry_run",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
        Some(valid_setup_proposal_body()),
    ));
    assert_eq!(200, status, "{response_body}");
    let json: serde_json::Value = serde_json::from_str(&response_body).expect("dry_run JSON");
    assert_eq!(true, json["valid"].as_bool().unwrap());
    assert_eq!("育苗", json["normalized"]["stages"][0]["name"].as_str().unwrap());
}

#[test]
fn post_masters_crop_setup_proposal_apply_persists_stages_and_blueprints() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop(user_id);

    let (status, response_body) = status_and_body(client.post(
        &format!(
            "/api/v1/masters/crops/{}/setup_proposal?mode=apply",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
        Some(valid_setup_proposal_body()),
    ));
    assert_eq!(201, status, "{response_body}");
    let json: serde_json::Value = serde_json::from_str(&response_body).expect("apply JSON");
    assert_eq!(true, json["valid"].as_bool().unwrap());
    assert_eq!(1, json["result"]["stage_ids"].as_array().unwrap().len());
    assert_eq!(1, json["result"]["blueprint_ids"].as_array().unwrap().len());

    let (stage_status, stage_body) = status_and_body(client.get(
        &format!("/api/v1/masters/crops/{}/crop_stages", seed.crop_id),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, stage_status, "{stage_body}");
    let stages: serde_json::Value = serde_json::from_str(&stage_body).expect("stages JSON");
    assert_eq!(1, stages.as_array().unwrap().len(), "{stage_body}");

    let (blueprint_status, blueprint_body) = status_and_body(client.get(
        &format!(
            "/api/v1/masters/crops/{}/task_schedule_blueprints",
            seed.crop_id
        ),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, blueprint_status, "{blueprint_body}");
    let blueprints: serde_json::Value = serde_json::from_str(&blueprint_body).expect("blueprints JSON");
    assert_eq!(1, blueprints.as_array().unwrap().len(), "{blueprint_body}");
}

#[test]
fn post_masters_crop_setup_proposal_with_api_key_authenticates() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop(user_id);

    let (generate_status, generate_body) = status_and_body(client.post(
        "/api/v1/api_keys/generate",
        Some(&session_id),
        &empty_headers(),
        None,
    ));
    assert_eq!(200, generate_status, "{generate_body}");
    let api_key = serde_json::from_str::<serde_json::Value>(&generate_body)
        .expect("api key JSON")["api_key"]
        .as_str()
        .expect("api_key")
        .to_string();

    let mut headers = empty_headers();
    headers.insert("Authorization".into(), format!("Bearer {api_key}"));

    let (status, response_body) = status_and_body(client.post(
        &format!(
            "/api/v1/masters/crops/{}/setup_proposal?mode=dry_run",
            seed.crop_id
        ),
        None,
        &headers,
        Some(valid_setup_proposal_body()),
    ));
    assert_eq!(200, status, "{response_body}");
    let json: serde_json::Value = serde_json::from_str(&response_body).expect("dry_run JSON");
    assert_eq!(true, json["valid"].as_bool().unwrap());
}

#[test]
fn post_crops_ai_create_returns_deprecation_metadata() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let response = client.post(
        "/api/v1/crops/ai_create",
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({ "name": "" })),
    );
    let headers = response.headers().clone();
    let (status, body) = status_and_body(response);
    assert_ne!(200, status, "empty crop name must not succeed: {body}");
    assert_builtin_generation_deprecated_headers(&headers, &body, "setup_proposal");
}

#[test]
fn post_fertilizes_ai_create_returns_deprecation_metadata() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let response = client.post(
        "/api/v1/fertilizes/ai_create",
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({ "name": "" })),
    );
    let headers = response.headers().clone();
    let (status, body) = status_and_body(response);
    assert_ne!(200, status, "empty fertilize name must not succeed: {body}");
    assert_builtin_generation_deprecated_headers(&headers, &body, "fertilizes");
}

#[test]
fn post_pests_ai_create_returns_deprecation_metadata() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let response = client.post(
        "/api/v1/pests/ai_create",
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({ "name": "" })),
    );
    let headers = response.headers().clone();
    let (status, body) = status_and_body(response);
    assert_ne!(200, status, "empty pest name must not succeed: {body}");
    assert_builtin_generation_deprecated_headers(&headers, &body, "pests");
}

#[test]
fn post_fertilizes_ai_update_returns_deprecation_metadata() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let response = client.post(
        "/api/v1/fertilizes/999999999/ai_update",
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({ "name": "test" })),
    );
    let headers = response.headers().clone();
    let (status, body) = status_and_body(response);
    assert_ne!(200, status, "missing fertilize must not succeed: {body}");
    assert_builtin_generation_deprecated_headers(&headers, &body, "fertilizes");
}

#[test]
fn post_pests_ai_update_returns_deprecation_metadata() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let response = client.post(
        "/api/v1/pests/999999999/ai_update",
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({ "name": "test" })),
    );
    let headers = response.headers().clone();
    let (status, body) = status_and_body(response);
    assert_ne!(200, status, "missing pest must not succeed: {body}");
    assert_builtin_generation_deprecated_headers(&headers, &body, "pests");
}

fn api_key_from_generate_response(body: &str) -> String {
    serde_json::from_str::<serde_json::Value>(body)
        .expect("api key JSON")["api_key"]
        .as_str()
        .expect("api_key")
        .to_string()
}

#[test]
fn post_api_keys_generate_is_idempotent_when_key_already_exists() {
    let client = ContractClient::from_env();
    // Use a dedicated mock user: parallel contract tests share one SQLite DB and
    // developer's api_key is mutated by other tests (generate/regenerate).
    let session_id = farmer_session_id(&client);

    let (first_status, first_body) = status_and_body(client.post(
        "/api/v1/api_keys/generate",
        Some(&session_id),
        &empty_headers(),
        None,
    ));
    assert_eq!(200, first_status, "{first_body}");
    let first_key = api_key_from_generate_response(&first_body);

    let (second_status, second_body) = status_and_body(client.post(
        "/api/v1/api_keys/generate",
        Some(&session_id),
        &empty_headers(),
        None,
    ));
    assert_eq!(200, second_status, "{second_body}");
    let second_key = api_key_from_generate_response(&second_body);
    assert_eq!(first_key, second_key, "generate must not rotate an existing key");
}

#[test]
fn post_api_keys_regenerate_invalidates_previous_key() {
    let client = ContractClient::from_env();
    // Dedicated mock user — see post_api_keys_generate_is_idempotent_when_key_already_exists.
    let session_id = researcher_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_masters_crop(user_id);

    let (generate_status, generate_body) = status_and_body(client.post(
        "/api/v1/api_keys/generate",
        Some(&session_id),
        &empty_headers(),
        None,
    ));
    assert_eq!(200, generate_status, "{generate_body}");
    let old_key = api_key_from_generate_response(&generate_body);

    let mut old_headers = empty_headers();
    old_headers.insert("Authorization".into(), format!("Bearer {old_key}"));
    let (old_auth_status, old_auth_body) = status_and_body(client.get(
        &format!("/api/v1/masters/crops/{}/crop_stages", seed.crop_id),
        None,
        &old_headers,
    ));
    assert_eq!(200, old_auth_status, "{old_auth_body}");

    let (regenerate_status, regenerate_body) = status_and_body(client.post(
        "/api/v1/api_keys/regenerate",
        Some(&session_id),
        &empty_headers(),
        None,
    ));
    assert_eq!(200, regenerate_status, "{regenerate_body}");
    let new_key = api_key_from_generate_response(&regenerate_body);
    assert_ne!(old_key, new_key, "regenerate must issue a new key");

    let (revoked_status, revoked_body) = status_and_body(client.get(
        &format!("/api/v1/masters/crops/{}/crop_stages", seed.crop_id),
        None,
        &old_headers,
    ));
    assert_eq!(401, revoked_status, "{revoked_body}");

    let mut new_headers = empty_headers();
    new_headers.insert("Authorization".into(), format!("Bearer {new_key}"));
    let (new_auth_status, new_auth_body) = status_and_body(client.get(
        &format!("/api/v1/masters/crops/{}/crop_stages", seed.crop_id),
        None,
        &new_headers,
    ));
    assert_eq!(200, new_auth_status, "{new_auth_body}");
}

#[test]
fn post_masters_crop_setup_proposal_apply_rate_limited_returns_429_with_retry_after() {
    let client = ContractClient::from_env();
    let session_id = farmer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let body = valid_setup_proposal_body();

    for attempt in 0..2 {
        let seed = seed_masters_crop(user_id);
        let path = format!(
            "/api/v1/masters/crops/{}/setup_proposal?mode=apply",
            seed.crop_id
        );
        let (status, response_body) = status_and_body(client.post(
            &path,
            Some(&session_id),
            &empty_headers(),
            Some(body.clone()),
        ));
        assert_eq!(201, status, "apply attempt {attempt}: {response_body}");
    }

    let seed = seed_masters_crop(user_id);
    let path = format!(
        "/api/v1/masters/crops/{}/setup_proposal?mode=apply",
        seed.crop_id
    );
    let response = client.post(
        &path,
        Some(&session_id),
        &empty_headers(),
        Some(body),
    );
    assert_eq!(429, response.status().as_u16());
    assert!(
        response.headers().get("retry-after").is_some(),
        "expected Retry-After header on 429"
    );
    let response_body = response.text().expect("rate limit body");
    let json: serde_json::Value = serde_json::from_str(&response_body).expect("rate limit JSON");
    assert_eq!("rate_limit", json["error"].as_str().unwrap());
}

#[test]
fn get_masters_farm_show_includes_weather_fields() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_farm_temperature_chart_completed(user_id);

    let path = format!("/api/v1/masters/farms/{}", seed.farm_id);
    let (status, body) = status_and_body(client.get(&path, Some(&session_id), &empty_headers()));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("farm show JSON");
    assert_eq!("completed", json["weather_data_status"].as_str().unwrap());
    assert_eq!(100, json["weather_data_progress"].as_i64().unwrap());
    assert_eq!(5, json["weather_data_fetched_years"].as_i64().unwrap());
    assert_eq!(5, json["weather_data_total_years"].as_i64().unwrap());
}

#[test]
fn get_masters_farms_list_includes_weather_fields() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_farm_temperature_chart_completed(user_id);

    let (status, body) = status_and_body(client.get("/api/v1/masters/farms", Some(&session_id), &empty_headers()));
    assert_eq!(200, status, "{body}");
    let farms: Vec<serde_json::Value> = serde_json::from_str(&body).expect("farm list JSON");
    let farm = farms
        .iter()
        .find(|f| f["id"].as_i64() == Some(seed.farm_id))
        .expect("seeded farm in list");
    assert_eq!("completed", farm["weather_data_status"].as_str().unwrap());
    assert_eq!(100, farm["weather_data_progress"].as_i64().unwrap());
    assert_eq!(5, farm["weather_data_fetched_years"].as_i64().unwrap());
    assert_eq!(5, farm["weather_data_total_years"].as_i64().unwrap());
}

#[test]
fn get_masters_farm_show_fetching_includes_weather_fields() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let farm_id = seed_farm_temperature_chart_fetching(user_id);

    let path = format!("/api/v1/masters/farms/{farm_id}");
    let (status, body) = status_and_body(client.get(&path, Some(&session_id), &empty_headers()));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("farm show JSON");
    assert_eq!("fetching", json["weather_data_status"].as_str().unwrap());
    assert!(json["weather_data_progress"].as_i64().is_some());
}

#[test]
fn get_farm_temperature_chart_completed_returns_observed_points() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_farm_temperature_chart_completed(user_id);

    let path = format!(
        "/api/v1/masters/farms/{}/temperature_chart?period=30d",
        seed.farm_id
    );
    let (status, body) = status_and_body(client.get(&path, Some(&session_id), &empty_headers()));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("temperature chart JSON");
    assert_eq!(seed.farm_id, json["farm_id"].as_i64().unwrap());
    assert_eq!("30d", json["period"].as_str().unwrap());
    assert_eq!(true, json["observed_only"].as_bool().unwrap());
    let points = json["points"].as_array().expect("points array");
    assert!(!points.is_empty());
    assert!(points.len() <= 30);
}

#[test]
fn get_farm_temperature_chart_fetching_returns_409() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let farm_id = seed_farm_temperature_chart_fetching(user_id);

    let path = format!("/api/v1/masters/farms/{farm_id}/temperature_chart");
    let (status, body) = status_and_body(client.get(&path, Some(&session_id), &empty_headers()));
    assert_eq!(409, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("409 JSON");
    assert_eq!("weather_data_not_ready", json["error"].as_str().unwrap());
    assert_eq!("fetching", json["weather_data_status"].as_str().unwrap());
}

#[test]
fn get_farm_temperature_chart_other_user_returns_404() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let seed = seed_farm_temperature_chart_completed(owner_id);

    let other_session = farmer_session_id(&client);
    let path = format!(
        "/api/v1/masters/farms/{}/temperature_chart",
        seed.farm_id
    );
    let (status, body) = status_and_body(client.get(&path, Some(&other_session), &empty_headers()));
    assert_eq!(404, status, "{body}");
}

