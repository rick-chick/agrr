//! R4 HTTP smoke: co-located agrr-server stack + routing (not domain rules — see agrr-domain / E2E).

mod support;

use agrr_domain::cultivation_plan::dtos::{
    WeatherRescheduleProposalPreviewRead, WeatherRescheduleProposalRead,
    WeatherRescheduleTriggerType,
};
use agrr_r4_contract::http::ContractClient;
use support::{
    agrr_regeneration_contract_available,     assert_builtin_generation_deprecated_headers,
    assert_cross_user_access_denied,
    assert_crop_task_template_api_removed,
    clear_plan_task_schedules, contract_api_session_id, developer_session_id, empty_headers,
    farmer_session_id, researcher_session_id,
    find_schedule_item, poll_task_schedule_sync_ready, schedule_item_ids_from_response,
    seed_masters_crop, seed_masters_crop_with_manual_blueprint, seed_masters_crop_with_stages,
    seed_masters_crop_with_stages_and_blueprints, seed_reference_crop_with_stage,
    ensure_agrr_daemon_for_contract, seed_task_schedule_regeneration_plan,
    seed_weather_reschedule_frost_forecast_plan,
    seed_work_record_plan, set_plan_task_schedule_sync_failed,
    insert_contract_fertilize, insert_contract_pesticide,
    seed_suffix,
    set_plan_task_schedule_sync_failed_raw_error, set_user_api_key_scopes, status_and_body,
    upload_ready_work_record_photo, user_id_for_session,
    seed_farm_temperature_chart_completed, seed_farm_temperature_chart_fetching,
    seed_farm_pending_weather, scheduler_auth_headers,
    ensure_farm_create_capacity_via_api, poll_farm_weather_completed,
    seed_weather_cache_for_farm_create_completion,
    seed_user_organization,
    seed_organization_membership,
    run_personal_organization_ensure_for_user,
    seed_user_farm_without_organization,
    seed_org_scoped_farm,
    seed_org_scoped_crop,
    seed_org_scoped_plan,
    seed_public_cultivation_plan,
    cable_subscribe_frame_type,
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
    assert_eq!(Some(2026), plan["plan_year"].as_i64().map(|y| y as i32));
    let farm_name = plan["farm_name"].as_str().expect("farm_name");
    assert!(farm_name.contains("Contract Work Record Farm"));
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
fn get_work_variance_portfolio_returns_farm_plan_rows_with_variance_stats() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let source = seed_work_record_plan(user_id);

    let sqlite_path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&sqlite_path).expect("open contract sqlite");
    conn.execute(
        "UPDATE task_schedule_items SET gdd_trigger = 100.0 WHERE id = ?1",
        rusqlite::params![source.task_schedule_item_id],
    )
    .expect("set gdd_trigger");

    let create_record_path = format!("/api/v1/plans/{}/work_records", source.plan_id);
    let (record_status, record_body) = status_and_body(client.post(
        &create_record_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "work_record": {
                "task_schedule_item_id": source.task_schedule_item_id,
                "actual_date": "2026-06-12",
                "notes": "variance portfolio contract seed"
            }
        })),
    ));
    assert_eq!(201, record_status, "{record_body}");
    let record_json: serde_json::Value =
        serde_json::from_str(&record_body).expect("create work_record JSON");
    let record_id = record_json["work_record"]["id"].as_i64().expect("record id");
    conn.execute(
        "UPDATE work_records SET gdd_at_actual = 110.0 WHERE id = ?1",
        rusqlite::params![record_id],
    )
    .expect("set gdd_at_actual");

    let pending_farm_id = seed_user_farm_without_organization(user_id);
    conn.execute(
        "INSERT INTO fields (farm_id, user_id, name, area, daily_fixed_cost, created_at, updated_at)
         VALUES (?1, ?2, 'Portfolio Pending Field', 40.0, 0, datetime('now'), datetime('now'))",
        rusqlite::params![pending_farm_id, user_id],
    )
    .expect("insert pending farm field");

    let (create_status, create_body) = status_and_body(client.post(
        "/api/v1/plans",
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "plan": {
                "farm_id": pending_farm_id,
                "plan_name": "Portfolio Pending Plan"
            }
        })),
    ));
    assert_eq!(201, create_status, "{create_body}");
    let create_json: serde_json::Value =
        serde_json::from_str(&create_body).expect("create plan JSON");
    let pending_plan_id = create_json["id"].as_i64().expect("pending plan id");

    let (status, body) = status_and_body(client.get(
        "/api/v1/work/variance_portfolio",
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, status, "{body}");
    let rows: Vec<serde_json::Value> = serde_json::from_str(&body).expect("variance portfolio JSON");
    assert!(rows.len() >= 2, "{body}");

    let completed_row = rows
        .iter()
        .find(|row| row["plan_id"].as_i64() == Some(source.plan_id))
        .expect("completed plan row");
    assert_eq!(source.farm_id, completed_row["farm_id"].as_i64().unwrap());
    assert_eq!(2026, completed_row["plan_year"].as_i64().unwrap());
    assert_eq!("completed", completed_row["status"].as_str().unwrap());
    assert_eq!(0, completed_row["unrecorded_count"].as_i64().unwrap());
    assert_eq!(1, completed_row["threshold_exceeded_count"].as_i64().unwrap());
    assert_eq!(1, completed_row["days_threshold_exceeded_count"].as_i64().unwrap());
    assert!(completed_row["carryover_not_imported"].is_boolean());
    assert!(completed_row["weather_trigger_count"].is_number());

    let pending_row = rows
        .iter()
        .find(|row| row["plan_id"].as_i64() == Some(pending_plan_id))
        .expect("pending plan row");
    assert_eq!(pending_farm_id, pending_row["farm_id"].as_i64().unwrap());
    assert_eq!("optimizing", pending_row["status"].as_str().unwrap());
    assert_eq!(0, pending_row["unrecorded_count"].as_i64().unwrap());
    assert!(!pending_row["carryover_not_imported"].as_bool().unwrap());
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
    assert!(record.get("gdd_at_actual").is_some());
    assert!(record.get("weather_snapshot").is_some());
}

#[test]
fn post_and_patch_work_records_persist_fertilize_and_pesticide_ids() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);
    let fertilize_id = insert_contract_fertilize(user_id, "Contract Fertilize");
    let pesticide_id = insert_contract_pesticide(user_id, seed.crop_id, "Contract Pesticide");

    let create_path = format!("/api/v1/plans/{}/work_records", seed.plan_id);
    let (create_status, create_body) = status_and_body(client.post(
        &create_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "work_record": {
                "name": "施肥散布",
                "actual_date": "2026-06-12",
                "fertilize_id": fertilize_id,
                "pesticide_id": pesticide_id
            }
        })),
    ));
    assert_eq!(201, create_status, "{create_body}");
    let create_json: serde_json::Value =
        serde_json::from_str(&create_body).expect("create work_record JSON");
    let record = &create_json["work_record"];
    let record_id = record["id"].as_i64().expect("record id");
    assert_eq!(fertilize_id, record["fertilize_id"].as_i64().unwrap());
    assert_eq!(pesticide_id, record["pesticide_id"].as_i64().unwrap());

    let patch_path = format!("/api/v1/plans/{}/work_records/{}", seed.plan_id, record_id);
    let (patch_status, patch_body) = status_and_body(client.patch(
        &patch_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "work_record": {
                "fertilize_id": null,
                "pesticide_id": pesticide_id
            }
        })),
    ));
    assert_eq!(200, patch_status, "{patch_body}");
    let patch_json: serde_json::Value =
        serde_json::from_str(&patch_body).expect("patch work_record JSON");
    let patched = &patch_json["work_record"];
    assert!(patched["fertilize_id"].is_null());
    assert_eq!(pesticide_id, patched["pesticide_id"].as_i64().unwrap());
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
    assert!(record.get("gdd_at_actual").is_some());
    assert!(record.get("weather_snapshot").is_some());
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
fn post_task_schedule_item_create_and_patch_update_returns_item_payload() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let create_path = format!("/api/v1/plans/{}/task_schedule/items", seed.plan_id);
    let (create_status, create_body) = status_and_body(client.post(
        &create_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "task_schedule_item": {
                "field_cultivation_id": seed.field_cultivation_id,
                "name": "手動追加作業",
                "scheduled_date": "2026-07-10"
            }
        })),
    ));
    assert_eq!(201, create_status, "{create_body}");
    let create_json: serde_json::Value =
        serde_json::from_str(&create_body).expect("create task schedule item JSON");
    let created_id = create_json["item"]["id"]
        .as_i64()
        .expect("created item id");
    assert_eq!("手動追加作業", create_json["item"]["name"].as_str().unwrap());
    assert_eq!(
        "2026-07-10",
        create_json["item"]["scheduled_date"].as_str().unwrap()
    );

    let update_path = format!(
        "/api/v1/plans/{}/task_schedule/items/{}",
        seed.plan_id, created_id
    );
    let (update_status, update_body) = status_and_body(client.patch(
        &update_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "task_schedule_item": {
                "scheduled_date": "2026-07-15"
            }
        })),
    ));
    assert_eq!(200, update_status, "{update_body}");
    let update_json: serde_json::Value =
        serde_json::from_str(&update_body).expect("update task schedule item JSON");
    assert_eq!(created_id, update_json["item"]["id"].as_i64().unwrap());
    assert_eq!(
        "2026-07-15",
        update_json["item"]["scheduled_date"].as_str().unwrap()
    );
    assert_eq!("rescheduled", update_json["item"]["status"].as_str().unwrap());

    let (seed_update_status, seed_update_body) = status_and_body(client.patch(
        &format!(
            "/api/v1/plans/{}/task_schedule/items/{}",
            seed.plan_id, seed.task_schedule_item_id
        ),
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "task_schedule_item": {
                "scheduled_date": "2026-06-20"
            }
        })),
    ));
    assert_eq!(200, seed_update_status, "{seed_update_body}");
    let seed_update_json: serde_json::Value =
        serde_json::from_str(&seed_update_body).expect("seed item update JSON");
    assert_eq!(
        "2026-06-20",
        seed_update_json["item"]["scheduled_date"].as_str().unwrap()
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
fn get_plan_vs_actual_summary_and_task_schedule_embed_variance_fields() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let sqlite_path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&sqlite_path).expect("open contract sqlite");
    conn.execute(
        "UPDATE task_schedule_items SET gdd_trigger = 100.0 WHERE id = ?1",
        rusqlite::params![seed.task_schedule_item_id],
    )
    .expect("set gdd_trigger");

    let create_path = format!("/api/v1/plans/{}/work_records", seed.plan_id);
    let (create_status, create_body) = status_and_body(client.post(
        &create_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "work_record": {
                "task_schedule_item_id": seed.task_schedule_item_id,
                "actual_date": "2026-06-12",
                "notes": "plan vs actual contract"
            }
        })),
    ));
    assert_eq!(201, create_status, "{create_body}");
    let create_json: serde_json::Value =
        serde_json::from_str(&create_body).expect("create work_record JSON");
    let record_id = create_json["work_record"]["id"].as_i64().expect("record id");
    conn.execute(
        "UPDATE work_records SET gdd_at_actual = 110.0 WHERE id = ?1",
        rusqlite::params![record_id],
    )
    .expect("set gdd_at_actual");

    let summary_path = format!("/api/v1/plans/{}/plan_vs_actual/summary", seed.plan_id);
    let (summary_status, summary_body) = status_and_body(client.get(
        &summary_path,
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, summary_status, "{summary_body}");
    let summary: serde_json::Value =
        serde_json::from_str(&summary_body).expect("plan_vs_actual summary JSON");
    assert_eq!(seed.plan_id, summary["plan_id"].as_i64().unwrap());
    assert_eq!(0, summary["unrecorded_count"].as_i64().unwrap());
    let categories = summary["categories"].as_array().expect("categories");
    assert!(!categories.is_empty(), "{summary_body}");
    assert!(categories[0]["average_delta_days"].is_number());
    let top_items = summary["top_variance_items"].as_array().expect("top_variance_items");
    assert_eq!(1, top_items.len());
    assert_eq!(seed.task_schedule_item_id, top_items[0]["item_id"].as_i64().unwrap());
    assert_eq!(10, top_items[0]["delta_days"].as_i64().unwrap());
    assert!(top_items[0]["gdd_at_actual"].is_number());
    assert!(top_items[0]["gdd_delta"].is_number());
    let proposals = summary["stage_gdd_calibration_proposals"]
        .as_array()
        .expect("stage_gdd_calibration_proposals");
    assert!(proposals.is_empty() || proposals[0]["average_gdd_delta"].is_number());

    let action_items = summary["action_required_items"]
        .as_array()
        .expect("action_required_items");
    assert_eq!(1, action_items.len());
    assert_eq!(
        seed.task_schedule_item_id,
        action_items[0]["item_id"].as_i64().unwrap()
    );
    assert_eq!("days", action_items[0]["exceedance_kind"].as_str().unwrap());

    let bp_proposals = summary["blueprint_timing_adjustment_proposals"]
        .as_array()
        .expect("blueprint_timing_adjustment_proposals");
    assert_eq!(1, bp_proposals.len());
    assert_eq!(seed.crop_id, bp_proposals[0]["crop_id"].as_i64().unwrap());
    assert!(bp_proposals[0]["average_delta_days"].is_number());

    let (schedule_status, schedule_body) = status_and_body(client.get(
        &format!("/api/v1/plans/{}/task_schedule", seed.plan_id),
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, schedule_status, "{schedule_body}");
    let schedule: serde_json::Value =
        serde_json::from_str(&schedule_body).expect("task schedule JSON");
    let item = schedule["fields"][0]["schedules"]["general"][0].clone();
    assert_eq!("2026-06-12", item["actual_date"].as_str().unwrap());
    assert_eq!(10, item["delta_days"].as_i64().unwrap());
    assert!(item["gdd_at_actual"].is_number());
    assert!(item["gdd_delta"].is_number());
}

#[test]
fn post_plan_create_with_carryover_persists_variance_learning_snapshot() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let source = seed_work_record_plan(user_id);

    let sqlite_path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&sqlite_path).expect("open contract sqlite");
    conn.execute(
        "UPDATE task_schedule_items SET gdd_trigger = 100.0 WHERE id = ?1",
        rusqlite::params![source.task_schedule_item_id],
    )
    .expect("set gdd_trigger");

    let create_record_path = format!("/api/v1/plans/{}/work_records", source.plan_id);
    let (record_status, record_body) = status_and_body(client.post(
        &create_record_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "work_record": {
                "task_schedule_item_id": source.task_schedule_item_id,
                "actual_date": "2026-06-12",
                "notes": "carryover contract seed"
            }
        })),
    ));
    assert_eq!(201, record_status, "{record_body}");
    let record_json: serde_json::Value =
        serde_json::from_str(&record_body).expect("create work_record JSON");
    let record_id = record_json["work_record"]["id"].as_i64().expect("record id");
    conn.execute(
        "UPDATE work_records SET gdd_at_actual = 110.0 WHERE id = ?1",
        rusqlite::params![record_id],
    )
    .expect("set gdd_at_actual");

    let target_farm_id = seed_user_farm_without_organization(user_id);
    conn.execute(
        "INSERT INTO fields (farm_id, user_id, name, area, daily_fixed_cost, created_at, updated_at)
         VALUES (?1, ?2, 'Carryover Target Field', 40.0, 0, datetime('now'), datetime('now'))",
        rusqlite::params![target_farm_id, user_id],
    )
    .expect("insert target field");

    let (create_status, create_body) = status_and_body(client.post(
        "/api/v1/plans",
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "plan": {
                "farm_id": target_farm_id,
                "plan_name": "Carryover Target Plan",
                "carryover_from_plan_id": source.plan_id
            }
        })),
    ));
    assert_eq!(201, create_status, "{create_body}");
    let create_json: serde_json::Value =
        serde_json::from_str(&create_body).expect("create plan JSON");
    let new_plan_id = create_json["id"].as_i64().expect("new plan id");

    let learning_path = format!("/api/v1/plans/{new_plan_id}/variance_learning");
    let (learning_status, learning_body) = status_and_body(client.get(
        &learning_path,
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, learning_status, "{learning_body}");
    let learning: serde_json::Value =
        serde_json::from_str(&learning_body).expect("variance learning JSON");
    assert_eq!(new_plan_id, learning["plan_id"].as_i64().unwrap());
    assert_eq!(source.plan_id, learning["source_plan_id"].as_i64().unwrap());
    let categories = learning["summary"]["categories"]
        .as_array()
        .expect("summary categories");
    assert!(!categories.is_empty(), "{learning_body}");
    assert!(categories[0]["average_delta_days"].is_number());
}

#[test]
fn post_plan_variance_learning_imports_snapshot_for_in_progress_plan() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let source = seed_work_record_plan(user_id);

    let sqlite_path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&sqlite_path).expect("open contract sqlite");
    conn.execute(
        "UPDATE task_schedule_items SET gdd_trigger = 100.0 WHERE id = ?1",
        rusqlite::params![source.task_schedule_item_id],
    )
    .expect("set gdd_trigger");

    let create_record_path = format!("/api/v1/plans/{}/work_records", source.plan_id);
    let (record_status, record_body) = status_and_body(client.post(
        &create_record_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "work_record": {
                "task_schedule_item_id": source.task_schedule_item_id,
                "actual_date": "2026-06-12",
                "notes": "in-progress carryover seed"
            }
        })),
    ));
    assert_eq!(201, record_status, "{record_body}");
    let record_json: serde_json::Value =
        serde_json::from_str(&record_body).expect("create work_record JSON");
    let record_id = record_json["work_record"]["id"].as_i64().expect("record id");
    conn.execute(
        "UPDATE work_records SET gdd_at_actual = 110.0 WHERE id = ?1",
        rusqlite::params![record_id],
    )
    .expect("set gdd_at_actual");

    let target_farm_id = seed_user_farm_without_organization(user_id);
    conn.execute(
        "INSERT INTO fields (farm_id, user_id, name, area, daily_fixed_cost, created_at, updated_at)
         VALUES (?1, ?2, 'In Progress Target Field', 40.0, 0, datetime('now'), datetime('now'))",
        rusqlite::params![target_farm_id, user_id],
    )
    .expect("insert target field");

    let (create_status, create_body) = status_and_body(client.post(
        "/api/v1/plans",
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "plan": {
                "farm_id": target_farm_id,
                "plan_name": "In Progress Target Plan"
            }
        })),
    ));
    assert_eq!(201, create_status, "{create_body}");
    let create_json: serde_json::Value =
        serde_json::from_str(&create_body).expect("create plan JSON");
    let target_plan_id = create_json["id"].as_i64().expect("target plan id");

    let import_path = format!("/api/v1/plans/{target_plan_id}/variance_learning");
    let (import_status, import_body) = status_and_body(client.post(
        &import_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "source_plan_id": source.plan_id
        })),
    ));
    assert_eq!(200, import_status, "{import_body}");
    let imported: serde_json::Value =
        serde_json::from_str(&import_body).expect("import variance learning JSON");
    assert_eq!(target_plan_id, imported["plan_id"].as_i64().unwrap());
    assert_eq!(source.plan_id, imported["source_plan_id"].as_i64().unwrap());

    let (learning_status, learning_body) = status_and_body(client.get(
        &import_path,
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, learning_status, "{learning_body}");
    let learning: serde_json::Value =
        serde_json::from_str(&learning_body).expect("variance learning JSON");
    assert_eq!(target_plan_id, learning["plan_id"].as_i64().unwrap());
    assert_eq!(source.plan_id, learning["source_plan_id"].as_i64().unwrap());
    let categories = learning["summary"]["categories"]
        .as_array()
        .expect("summary categories");
    assert!(!categories.is_empty(), "{learning_body}");
}

#[test]
fn post_plan_variance_learning_import_other_user_returns_not_found() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let owner_source = seed_work_record_plan(owner_id);

    let other_session = farmer_session_id(&client);
    let other_id = user_id_for_session(&client, &other_session);
    let other_target_farm_id = seed_user_farm_without_organization(other_id);
    let sqlite_path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&sqlite_path).expect("open contract sqlite");
    conn.execute(
        "INSERT INTO fields (farm_id, user_id, name, area, daily_fixed_cost, created_at, updated_at)
         VALUES (?1, ?2, 'Other User Target Field', 40.0, 0, datetime('now'), datetime('now'))",
        rusqlite::params![other_target_farm_id, other_id],
    )
    .expect("insert other user target field");

    let (create_status, create_body) = status_and_body(client.post(
        "/api/v1/plans",
        Some(&other_session),
        &empty_headers(),
        Some(serde_json::json!({
            "plan": {
                "farm_id": other_target_farm_id,
                "plan_name": "Other User Target Plan"
            }
        })),
    ));
    assert_eq!(201, create_status, "{create_body}");
    let create_json: serde_json::Value =
        serde_json::from_str(&create_body).expect("create plan JSON");
    let other_target_plan_id = create_json["id"].as_i64().expect("other target plan id");

    let import_path = format!("/api/v1/plans/{other_target_plan_id}/variance_learning");
    let (status, body) = status_and_body(client.post(
        &import_path,
        Some(&owner_session),
        &empty_headers(),
        Some(serde_json::json!({
            "source_plan_id": owner_source.plan_id
        })),
    ));
    assert_cross_user_access_denied(status, &body);

    let (learning_status, learning_body) = status_and_body(client.get(
        &import_path,
        Some(&other_session),
        &empty_headers(),
    ));
    assert_eq!(404, learning_status, "{learning_body}");
}

#[test]
fn get_weather_reschedule_proposals_authenticated_returns_empty_array() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let path = format!("/api/v1/plans/{}/weather_reschedule_proposals", seed.plan_id);
    let (status, body) = status_and_body(client.get(&path, Some(&session_id), &empty_headers()));
    assert_eq!(200, status, "{body}");
    let proposals: Vec<serde_json::Value> =
        serde_json::from_str(&body).expect("weather_reschedule_proposals JSON array");
    assert!(proposals.is_empty(), "{body}");
}

#[test]
fn get_weather_reschedule_proposals_unauthenticated_returns_401() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let path = format!("/api/v1/plans/{}/weather_reschedule_proposals", seed.plan_id);
    let (status, body) = status_and_body(client.get(&path, None, &empty_headers()));
    assert_eq!(401, status, "{body}");
}

#[test]
fn get_weather_reschedule_proposals_other_user_returns_not_found() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let seed = seed_work_record_plan(owner_id);

    let path = format!("/api/v1/plans/{}/weather_reschedule_proposals", seed.plan_id);
    let (owner_status, owner_body) =
        status_and_body(client.get(&path, Some(&owner_session), &empty_headers()));
    assert_eq!(200, owner_status, "{owner_body}");

    let other_session = farmer_session_id(&client);
    let (status, body) = status_and_body(client.get(&path, Some(&other_session), &empty_headers()));
    assert_cross_user_access_denied(status, &body);
}

#[test]
fn get_weather_reschedule_proposals_authenticated_returns_frost_forecast_proposal_shape() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_weather_reschedule_frost_forecast_plan(user_id);

    let path = format!("/api/v1/plans/{}/weather_reschedule_proposals", seed.plan_id);
    let (status, body) = status_and_body(client.get(&path, Some(&session_id), &empty_headers()));
    assert_eq!(200, status, "{body}");
    let proposals: Vec<WeatherRescheduleProposalRead> =
        serde_json::from_str(&body).expect("weather_reschedule_proposals JSON array");
    assert_eq!(1, proposals.len(), "{body}");
    let proposal = &proposals[0];
    assert_eq!(seed.proposal_id, proposal.id);
    assert_eq!(WeatherRescheduleTriggerType::FrostForecast, proposal.trigger_type);
    assert!(!proposal.severity.is_empty());
    assert!(proposal.rationale.is_object());
    assert_eq!(1, proposal.moves.len());
    assert_eq!("move", proposal.moves[0]["action"].as_str().unwrap());
}

#[test]
fn post_weather_reschedule_proposal_preview_unauthenticated_returns_401() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let path = format!(
        "/api/v1/plans/{}/weather_reschedule_proposals/frost_forecast:1:1/preview",
        seed.plan_id
    );
    let (status, body) = status_and_body(client.post(&path, None, &empty_headers(), None));
    assert_eq!(401, status, "{body}");
}

#[test]
fn post_weather_reschedule_proposal_preview_unknown_proposal_returns_not_found() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let path = format!(
        "/api/v1/plans/{}/weather_reschedule_proposals/missing:1:1/preview",
        seed.plan_id
    );
    let (status, body) = status_and_body(client.post(
        &path,
        Some(&session_id),
        &empty_headers(),
        None,
    ));
    assert_eq!(404, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("preview not_found JSON");
    assert_eq!(json["errors"][0], "not_found");
}

#[test]
fn post_weather_reschedule_proposal_preview_other_user_returns_not_found() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let seed = seed_work_record_plan(owner_id);

    let path = format!(
        "/api/v1/plans/{}/weather_reschedule_proposals/frost_forecast:1:1/preview",
        seed.plan_id
    );
    let other_session = farmer_session_id(&client);
    let (status, body) = status_and_body(client.post(
        &path,
        Some(&other_session),
        &empty_headers(),
        None,
    ));
    assert_cross_user_access_denied(status, &body);
}

#[test]
fn post_weather_reschedule_proposal_preview_authenticated_returns_preview_shape() {
    if !agrr_regeneration_contract_available() {
        eprintln!("skip: agrr binary unavailable for weather reschedule preview contract test");
        return;
    }
    ensure_agrr_daemon_for_contract();
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_weather_reschedule_frost_forecast_plan(user_id);

    let path = format!(
        "/api/v1/plans/{}/weather_reschedule_proposals/{}/preview",
        seed.plan_id, seed.proposal_id
    );
    let (status, body) = status_and_body(client.post(
        &path,
        Some(&session_id),
        &empty_headers(),
        None,
    ));
    assert_eq!(200, status, "{body}");
    let preview: WeatherRescheduleProposalPreviewRead =
        serde_json::from_str(&body).expect("weather reschedule preview JSON");
    assert_eq!(seed.proposal_id, preview.proposal_id);
    assert_eq!(seed.proposal_id, preview.proposal.id);
    assert_eq!(WeatherRescheduleTriggerType::FrostForecast, preview.proposal.trigger_type);
    assert!(!preview.moves.is_empty());
    assert!(!preview.before.field_schedules.is_empty());
    assert!(!preview.after.field_schedules.is_empty());
}

#[test]
fn get_plan_variance_learning_includes_proposal_application_progress() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let source = seed_work_record_plan(user_id);

    let sqlite_path =
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH must be set for contract seed");
    let conn = rusqlite::Connection::open(&sqlite_path).expect("open contract sqlite");
    conn.execute(
        "UPDATE task_schedule_items SET gdd_trigger = 100.0 WHERE id = ?1",
        rusqlite::params![source.task_schedule_item_id],
    )
    .expect("set gdd_trigger");

    let create_record_path = format!("/api/v1/plans/{}/work_records", source.plan_id);
    let (record_status, record_body) = status_and_body(client.post(
        &create_record_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "work_record": {
                "task_schedule_item_id": source.task_schedule_item_id,
                "actual_date": "2026-06-12",
                "notes": "proposal progress contract seed"
            }
        })),
    ));
    assert_eq!(201, record_status, "{record_body}");
    let record_json: serde_json::Value =
        serde_json::from_str(&record_body).expect("create work_record JSON");
    let record_id = record_json["work_record"]["id"].as_i64().expect("record id");
    conn.execute(
        "UPDATE work_records SET gdd_at_actual = 110.0 WHERE id = ?1",
        rusqlite::params![record_id],
    )
    .expect("set gdd_at_actual");

    let target_farm_id = seed_user_farm_without_organization(user_id);
    conn.execute(
        "INSERT INTO fields (farm_id, user_id, name, area, daily_fixed_cost, created_at, updated_at)
         VALUES (?1, ?2, 'Proposal Progress Field', 40.0, 0, datetime('now'), datetime('now'))",
        rusqlite::params![target_farm_id, user_id],
    )
    .expect("insert target field");

    let (create_status, create_body) = status_and_body(client.post(
        "/api/v1/plans",
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "plan": {
                "farm_id": target_farm_id,
                "plan_name": "Proposal Progress Plan",
                "carryover_from_plan_id": source.plan_id
            }
        })),
    ));
    assert_eq!(201, create_status, "{create_body}");
    let create_json: serde_json::Value =
        serde_json::from_str(&create_body).expect("create plan JSON");
    let plan_id = create_json["id"].as_i64().expect("plan id");

    let learning_path = format!("/api/v1/plans/{plan_id}/variance_learning");
    let proposal_key = "stage_gdd:1:2";

    let (patch_status, patch_body) = status_and_body(client.patch(
        &learning_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "proposal_application_progress": {
                proposal_key: "dismissed"
            }
        })),
    ));
    assert_eq!(200, patch_status, "{patch_body}");
    let patched: serde_json::Value =
        serde_json::from_str(&patch_body).expect("patch variance learning JSON");
    let progress = patched["proposal_application_progress"]
        .as_object()
        .expect("proposal_application_progress object");
    assert_eq!("dismissed", progress[proposal_key].as_str().unwrap());

    let (get_status, get_body) = status_and_body(client.get(
        &learning_path,
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, get_status, "{get_body}");
    let learning: serde_json::Value =
        serde_json::from_str(&get_body).expect("variance learning JSON");
    let get_progress = learning["proposal_application_progress"]
        .as_object()
        .expect("proposal_application_progress on GET");
    assert_eq!("dismissed", get_progress[proposal_key].as_str().unwrap());
}

#[test]
fn get_plan_variance_learning_includes_reorganize_orchestration_progress() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);
    let learning_path = format!("/api/v1/plans/{}/variance_learning", seed.plan_id);

    let (patch_status, patch_body) = status_and_body(client.patch(
        &learning_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "reorganize_orchestration_progress": {
                "placement": true,
                "return_to_learn": true
            }
        })),
    ));
    assert_eq!(200, patch_status, "{patch_body}");
    let patched: serde_json::Value =
        serde_json::from_str(&patch_body).expect("patch variance learning JSON");
    let patched_orchestration = patched["reorganize_orchestration_progress"]
        .as_object()
        .expect("patched reorganize_orchestration_progress");
    assert_eq!(true, patched_orchestration["placement"].as_bool().unwrap());
    assert_eq!(true, patched_orchestration["return_to_learn"].as_bool().unwrap());

    let (get_status, get_body) = status_and_body(client.get(
        &learning_path,
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, get_status, "{get_body}");
    let learning: serde_json::Value =
        serde_json::from_str(&get_body).expect("variance learning JSON");
    let orchestration = learning["reorganize_orchestration_progress"]
        .as_object()
        .expect("reorganize_orchestration_progress object");
    assert_eq!(true, orchestration["placement"].as_bool().unwrap());
    assert_eq!(false, orchestration["regenerate"].as_bool().unwrap());
    assert_eq!(false, orchestration["sync_verify"].as_bool().unwrap());
    assert_eq!(true, orchestration["return_to_learn"].as_bool().unwrap());

    let (round_trip_status, round_trip_body) = status_and_body(client.get(
        &learning_path,
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, round_trip_status, "{round_trip_body}");
    let round_trip: serde_json::Value =
        serde_json::from_str(&round_trip_body).expect("round trip variance learning JSON");
    let round_trip_orchestration = round_trip["reorganize_orchestration_progress"]
        .as_object()
        .expect("round trip reorganize_orchestration_progress");
    assert_eq!(true, round_trip_orchestration["placement"].as_bool().unwrap());
    assert_eq!(true, round_trip_orchestration["return_to_learn"].as_bool().unwrap());

    let (regen_status, regen_body) = status_and_body(client.patch(
        &learning_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "reorganize_orchestration_progress": {
                "regenerate": true,
                "return_to_learn": false
            }
        })),
    ));
    assert_eq!(200, regen_status, "{regen_body}");
    let regen: serde_json::Value =
        serde_json::from_str(&regen_body).expect("regenerate patch JSON");
    let regen_orchestration = regen["reorganize_orchestration_progress"]
        .as_object()
        .expect("regenerate orchestration progress");
    assert_eq!(true, regen_orchestration["placement"].as_bool().unwrap());
    assert_eq!(true, regen_orchestration["regenerate"].as_bool().unwrap());
    assert_eq!(false, regen_orchestration["return_to_learn"].as_bool().unwrap());
}

#[test]
fn patch_plan_variance_learning_persists_reorganize_pipeline_run_state() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);
    let learning_path = format!("/api/v1/plans/{}/variance_learning", seed.plan_id);

    let (patch_status, patch_body) = status_and_body(client.patch(
        &learning_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "reorganize_orchestration_progress": {
                "pipeline_active": true,
                "current_phase": "placement",
                "last_error": null
            }
        })),
    ));
    assert_eq!(200, patch_status, "{patch_body}");
    let patched: serde_json::Value =
        serde_json::from_str(&patch_body).expect("patch variance learning JSON");
    let patched_orchestration = patched["reorganize_orchestration_progress"]
        .as_object()
        .expect("patched reorganize_orchestration_progress");
    assert_eq!(true, patched_orchestration["pipeline_active"].as_bool().unwrap());
    assert_eq!("placement", patched_orchestration["current_phase"].as_str().unwrap());
    assert!(patched_orchestration["last_error"].is_null());

    let (failed_status, failed_body) = status_and_body(client.patch(
        &learning_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "reorganize_orchestration_progress": {
                "current_phase": "failed",
                "last_error": "optimization timeout"
            }
        })),
    ));
    assert_eq!(200, failed_status, "{failed_body}");
    let failed: serde_json::Value =
        serde_json::from_str(&failed_body).expect("failed patch JSON");
    let failed_orchestration = failed["reorganize_orchestration_progress"]
        .as_object()
        .expect("failed orchestration progress");
    assert_eq!("failed", failed_orchestration["current_phase"].as_str().unwrap());
    assert_eq!(
        "optimization timeout",
        failed_orchestration["last_error"].as_str().unwrap()
    );

    let (get_status, get_body) = status_and_body(client.get(
        &learning_path,
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, get_status, "{get_body}");
    let learning: serde_json::Value =
        serde_json::from_str(&get_body).expect("variance learning JSON");
    let orchestration = learning["reorganize_orchestration_progress"]
        .as_object()
        .expect("reorganize_orchestration_progress object");
    assert_eq!(true, orchestration["pipeline_active"].as_bool().unwrap());
    assert_eq!("failed", orchestration["current_phase"].as_str().unwrap());
    assert_eq!(
        "optimization timeout",
        orchestration["last_error"].as_str().unwrap()
    );
}

#[test]
fn get_plan_variance_learning_includes_learn_handoff() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);
    let learning_path = format!("/api/v1/plans/{}/variance_learning", seed.plan_id);

    let post_master_payload = serde_json::json!({
        "kind": "stage_gdd",
        "cropId": 1,
        "cropName": "Tomato",
        "stageId": 2,
        "stageName": "Vegetative",
        "appliedRequiredGdd": 150
    });

    let (patch_status, patch_body) = status_and_body(client.patch(
        &learning_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "learn_handoff": {
                "post_master_payload": post_master_payload
            }
        })),
    ));
    assert_eq!(200, patch_status, "{patch_body}");
    let patched: serde_json::Value =
        serde_json::from_str(&patch_body).expect("patch variance learning JSON");
    let handoff = patched["learn_handoff"]
        .as_object()
        .expect("learn_handoff object");
    assert_eq!(
        post_master_payload,
        handoff["post_master_payload"].clone()
    );

    let (get_status, get_body) = status_and_body(client.get(
        &learning_path,
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, get_status, "{get_body}");
    let learning: serde_json::Value =
        serde_json::from_str(&get_body).expect("variance learning JSON");
    let get_handoff = learning["learn_handoff"]
        .as_object()
        .expect("learn_handoff on GET");
    assert_eq!(
        post_master_payload,
        get_handoff["post_master_payload"].clone()
    );

    let (clear_status, clear_body) = status_and_body(client.patch(
        &learning_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "learn_handoff": {
                "post_master_payload": null
            }
        })),
    ));
    assert_eq!(200, clear_status, "{clear_body}");
    let cleared: serde_json::Value =
        serde_json::from_str(&clear_body).expect("clear handoff JSON");
    assert!(
        cleared["learn_handoff"]
            .as_object()
            .expect("cleared learn_handoff")
            .get("post_master_payload")
            .is_none(),
        "{clear_body}"
    );
}

#[test]
fn patch_plan_variance_learning_invalid_status_returns_unprocessable() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);
    let learning_path = format!("/api/v1/plans/{}/variance_learning", seed.plan_id);

    let (status, body) = status_and_body(client.patch(
        &learning_path,
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "proposal_application_progress": {
                "stage_gdd:1:2": "invalid_status"
            }
        })),
    ));
    assert_eq!(422, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("error JSON");
    assert!(json["errors"].as_array().is_some(), "{body}");
}

#[test]
fn post_plan_variance_learning_reoptimize_enqueues_optimization_chain() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);
    let reoptimize_path = format!(
        "/api/v1/plans/{}/variance_learning/reoptimize",
        seed.plan_id
    );

    let (status, body) = status_and_body(client.post(
        &reoptimize_path,
        Some(&session_id),
        &empty_headers(),
        None,
    ));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("reoptimize JSON");
    assert_eq!(true, json["success"].as_bool().unwrap());
    assert_eq!(true, json["optimization_enqueued"].as_bool().unwrap());
    assert_eq!(seed.plan_id, json["plan_id"].as_i64().unwrap());

    let path = std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH");
    let conn = rusqlite::Connection::open(&path).expect("open sqlite");
    let mut optimization_phase: Option<String> = None;
    for _ in 0..100 {
        optimization_phase = conn
            .query_row(
                "SELECT optimization_phase FROM cultivation_plans WHERE id = ?1",
                rusqlite::params![seed.plan_id],
                |row| row.get(0),
            )
            .expect("optimization_phase");
        if optimization_phase
            .as_deref()
            .is_some_and(|phase| !phase.is_empty())
        {
            break;
        }
        std::thread::sleep(std::time::Duration::from_millis(20));
    }
    assert!(
        optimization_phase
            .as_deref()
            .is_some_and(|phase| !phase.is_empty()),
        "optimization job chain must start for plan {} (phase={optimization_phase:?})",
        seed.plan_id
    );

    let learning_path = format!("/api/v1/plans/{}/variance_learning", seed.plan_id);
    let (get_status, get_body) = status_and_body(client.get(
        &learning_path,
        Some(&session_id),
        &empty_headers(),
    ));
    assert_eq!(200, get_status, "{get_body}");
    let learning: serde_json::Value =
        serde_json::from_str(&get_body).expect("variance learning JSON after reoptimize");
    let orchestration = learning["reorganize_orchestration_progress"]
        .as_object()
        .expect("reorganize_orchestration_progress after reoptimize");
    assert_eq!(
        true,
        orchestration["pipeline_active"].as_bool().unwrap(),
        "reoptimize must persist pipeline_active server-side (#1107 regression)"
    );
    assert_eq!(
        "optimizing",
        orchestration["current_phase"].as_str().unwrap(),
        "reoptimize must set current_phase=optimizing before chain steps run"
    );
}

#[test]
fn post_plan_variance_learning_reoptimize_other_user_returns_not_found() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let seed = seed_work_record_plan(owner_id);

    let other_session = farmer_session_id(&client);
    let other_id = user_id_for_session(&client, &other_session);
    assert_ne!(owner_id, other_id, "contract test requires distinct users");

    let reoptimize_path = format!(
        "/api/v1/plans/{}/variance_learning/reoptimize",
        seed.plan_id
    );
    let (status, body) = status_and_body(client.post(
        &reoptimize_path,
        Some(&other_session),
        &empty_headers(),
        None,
    ));
    assert_eq!(404, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("error JSON");
    assert!(json["errors"].as_array().is_some(), "{body}");
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
fn get_task_schedule_category_pest_control_filters_to_pest_control_bucket() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let seed = seed_work_record_plan(user_id);

    let path = std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH");
    let conn = rusqlite::Connection::open(&path).expect("open sqlite");
    conn.execute(
        "INSERT INTO task_schedules (
           cultivation_plan_id, field_cultivation_id, category, status, source,
           generated_at, created_at, updated_at
         ) VALUES (?1, ?2, 'pest_control', 'active', 'agrr', datetime('now'), datetime('now'), datetime('now'))",
        rusqlite::params![seed.plan_id, seed.field_cultivation_id],
    )
    .expect("insert pest_control task_schedule");
    let pest_schedule_id = conn.last_insert_rowid();
    conn.execute(
        "INSERT INTO task_schedule_items (
           task_schedule_id, task_type, name, source, stage_name, stage_order,
           scheduled_date, agricultural_task_id, status, created_at, updated_at
         ) VALUES (
           ?1, 'preventive_spray', '予防散布', 'agrr', '生育期', 2,
           '2026-06-03', ?2, 'planned', datetime('now'), datetime('now')
         )",
        rusqlite::params![pest_schedule_id, seed.agricultural_task_id],
    )
    .expect("insert pest_control task_schedule_item");

    let (status, body) = status_and_body(client.get(
        &format!(
            "/api/v1/plans/{}/task_schedule?scope=plan&category=pest_control",
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
    let pest_control = fields[0]["schedules"]["pest_control"]
        .as_array()
        .expect("pest_control schedule bucket");
    assert!(
        general.is_empty(),
        "category=pest_control must exclude general items: {body}"
    );
    assert_eq!(1, pest_control.len(), "{body}");
    assert_eq!("preventive_spray", pest_control[0]["task_type"].as_str().unwrap());
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
fn post_crops_ai_create_unauthenticated_returns_401() {
    let client = ContractClient::from_env();
    let (status, body) = status_and_body(client.post(
        "/api/v1/crops/ai_create",
        None,
        &empty_headers(),
        Some(serde_json::json!({ "name": "tomato" })),
    ));
    assert_eq!(401, status, "{body}");
}

#[test]
fn post_fertilizes_ai_create_unauthenticated_returns_401() {
    let client = ContractClient::from_env();
    let (status, body) = status_and_body(client.post(
        "/api/v1/fertilizes/ai_create",
        None,
        &empty_headers(),
        Some(serde_json::json!({ "name": "urea" })),
    ));
    assert_eq!(401, status, "{body}");
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
fn post_masters_fertilizes_allows_same_name_for_different_users() {
    let client = ContractClient::from_env();
    let farmer = farmer_session_id(&client);
    let researcher = researcher_session_id(&client);
    let shared_name = format!("E2E Baseline Fertilize {}", seed_suffix());
    let body = serde_json::json!({
        "fertilize": {
            "name": shared_name,
            "n": 10,
            "p": 5,
            "k": 5,
            "package_size": 25
        }
    });

    let (farmer_status, farmer_body) = status_and_body(client.post(
        "/api/v1/masters/fertilizes",
        Some(&farmer),
        &empty_headers(),
        Some(body.clone()),
    ));
    assert_eq!(201, farmer_status, "{farmer_body}");

    let (researcher_status, researcher_body) = status_and_body(client.post(
        "/api/v1/masters/fertilizes",
        Some(&researcher),
        &empty_headers(),
        Some(body),
    ));
    assert_eq!(
        201, researcher_status,
        "same fertilize name must succeed for another user: {researcher_body}"
    );
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
    // Dedicated mock user — parallel contract tests must not share api_key mutations.
    let session_id = contract_api_session_id(&client);
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
fn masters_api_key_read_scope_allows_get_and_denies_post() {
    let client = ContractClient::from_env();
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
    let api_key = api_key_from_generate_response(&generate_body);
    set_user_api_key_scopes(user_id, r#"["masters:read"]"#);

    let mut headers = empty_headers();
    headers.insert("Authorization".into(), format!("Bearer {api_key}"));

    let (get_status, get_body) = status_and_body(client.get(
        &format!("/api/v1/masters/crops/{}", seed.crop_id),
        None,
        &headers,
    ));
    assert_eq!(200, get_status, "{get_body}");

    let (post_status, post_body) = status_and_body(client.post(
        "/api/v1/masters/crops",
        None,
        &headers,
        Some(serde_json::json!({ "crop": { "name": "scope-test-crop" } })),
    ));
    assert_eq!(403, post_status, "{post_body}");
    let post_json: serde_json::Value = serde_json::from_str(&post_body).expect("forbidden JSON");
    assert_eq!(
        Some("insufficient_scope"),
        post_json["error_code"].as_str(),
        "{post_body}"
    );
}

#[test]
fn masters_api_key_write_scope_allows_post() {
    let client = ContractClient::from_env();
    let session_id = farmer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);

    let (generate_status, generate_body) = status_and_body(client.post(
        "/api/v1/api_keys/generate",
        Some(&session_id),
        &empty_headers(),
        None,
    ));
    assert_eq!(200, generate_status, "{generate_body}");
    let api_key = api_key_from_generate_response(&generate_body);
    set_user_api_key_scopes(user_id, r#"["masters:read","masters:write"]"#);

    let mut headers = empty_headers();
    headers.insert("Authorization".into(), format!("Bearer {api_key}"));

    let (post_status, post_body) = status_and_body(client.post(
        "/api/v1/masters/crops",
        None,
        &headers,
        Some(serde_json::json!({ "crop": { "name": "scope-write-crop" } })),
    ));
    assert_eq!(201, post_status, "{post_body}");
}

#[test]
fn masters_api_key_read_scope_denies_setup_proposal_apply() {
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
    let api_key = api_key_from_generate_response(&generate_body);
    set_user_api_key_scopes(user_id, r#"["masters:read"]"#);

    let mut headers = empty_headers();
    headers.insert("Authorization".into(), format!("Bearer {api_key}"));

    let (apply_status, apply_body) = status_and_body(client.post(
        &format!(
            "/api/v1/masters/crops/{}/setup_proposal?mode=apply",
            seed.crop_id
        ),
        None,
        &headers,
        Some(valid_setup_proposal_body()),
    ));
    assert_eq!(403, apply_status, "{apply_body}");
}

#[test]
fn post_api_keys_generate_defaults_to_read_only_scopes() {
    let client = ContractClient::from_env();
    let session_id = researcher_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);

    let (status, body) = status_and_body(client.post(
        "/api/v1/api_keys/regenerate",
        Some(&session_id),
        &empty_headers(),
        None,
    ));
    assert_eq!(200, status, "{body}");

    let conn = rusqlite::Connection::open(
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH"),
    )
    .expect("open sqlite");
    let scopes: String = conn
        .query_row(
            "SELECT api_key_scopes FROM users WHERE id = ?1",
            rusqlite::params![user_id],
            |row| row.get(0),
        )
        .expect("api_key_scopes");
    assert_eq!(r#"["masters:read"]"#, scopes);
}

#[test]
fn get_auth_me_returns_masked_api_key_not_plaintext() {
    let client = ContractClient::from_env();
    let session_id = contract_api_session_id(&client);

    let (gen_status, gen_body) = status_and_body(client.post(
        "/api/v1/api_keys/generate",
        Some(&session_id),
        &empty_headers(),
        None,
    ));
    assert_eq!(200, gen_status, "{gen_body}");
    let full_key = api_key_from_generate_response(&gen_body);

    let (me_status, me_body) =
        status_and_body(client.get("/api/v1/auth/me", Some(&session_id), &empty_headers()));
    assert_eq!(200, me_status, "{me_body}");
    let me_json: serde_json::Value = serde_json::from_str(&me_body).expect("me JSON");
    let me_key = me_json["user"]["api_key"]
        .as_str()
        .expect("api_key");
    assert_ne!(me_key, full_key);
    assert!(me_key.contains("****"), "expected masked api_key in /me: {me_key}");
}

#[test]
fn get_masters_with_query_api_key_is_rejected() {
    let client = ContractClient::from_env();
    let session_id = contract_api_session_id(&client);

    let (gen_status, gen_body) = status_and_body(client.post(
        "/api/v1/api_keys/generate",
        Some(&session_id),
        &empty_headers(),
        None,
    ));
    assert_eq!(200, gen_status, "{gen_body}");
    let api_key = api_key_from_generate_response(&gen_body);

    let path = format!("/api/v1/masters/crops?api_key={api_key}");
    let (status, body) = status_and_body(client.get(&path, None, &empty_headers()));
    assert_eq!(401, status, "{body}");
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

#[test]
fn post_masters_farm_create_starts_weather_fetch() {
    let client = ContractClient::from_env();
    let session_id = farmer_session_id(&client);
    ensure_farm_create_capacity_via_api(&client, &session_id);

    let (create_status, create_body) = status_and_body(client.post(
        "/api/v1/masters/farms",
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "farm": {
                "name": "Contract Weather Fetch Farm",
                "region": "jp",
                "latitude": 35.6895,
                "longitude": 139.6917
            }
        })),
    ));
    assert_eq!(201, create_status, "{create_body}");
    let create_json: serde_json::Value =
        serde_json::from_str(&create_body).expect("create farm JSON");
    let farm_id = create_json["id"].as_i64().expect("farm id");
    assert_eq!("fetching", create_json["weather_data_status"].as_str().unwrap());
    assert!(create_json["weather_data_total_years"].as_i64().unwrap() > 0);

    let path = format!("/api/v1/masters/farms/{farm_id}");
    let (show_status, show_body) = status_and_body(client.get(&path, Some(&session_id), &empty_headers()));
    assert_eq!(200, show_status, "{show_body}");
    let show_json: serde_json::Value = serde_json::from_str(&show_body).expect("farm show JSON");
    assert_eq!("fetching", show_json["weather_data_status"].as_str().unwrap());
    assert!(show_json["weather_data_total_years"].as_i64().unwrap() > 0);
}

#[test]
fn post_masters_farm_create_weather_fetch_reaches_completed() {
    let client = ContractClient::from_env();
    let session_id = farmer_session_id(&client);
    ensure_farm_create_capacity_via_api(&client, &session_id);
    let cache = seed_weather_cache_for_farm_create_completion();

    let (create_status, create_body) = status_and_body(client.post(
        "/api/v1/masters/farms",
        Some(&session_id),
        &empty_headers(),
        Some(serde_json::json!({
            "farm": {
                "name": "Contract Weather Complete Farm",
                "region": "jp",
                "latitude": cache.latitude,
                "longitude": cache.longitude
            }
        })),
    ));
    assert_eq!(201, create_status, "{create_body}");
    let create_json: serde_json::Value =
        serde_json::from_str(&create_body).expect("create farm JSON");
    let farm_id = create_json["id"].as_i64().expect("farm id");
    assert_eq!("fetching", create_json["weather_data_status"].as_str().unwrap());

    poll_farm_weather_completed(&client, &session_id, farm_id);

    let chart_path = format!("/api/v1/masters/farms/{farm_id}/temperature_chart?period=90d");
    let (chart_status, chart_body) =
        status_and_body(client.get(&chart_path, Some(&session_id), &empty_headers()));
    assert_eq!(200, chart_status, "{chart_body}");
    let chart_json: serde_json::Value =
        serde_json::from_str(&chart_body).expect("temperature chart JSON");
    assert_eq!(farm_id, chart_json["farm_id"].as_i64().unwrap());
    assert_eq!("90d", chart_json["period"].as_str().unwrap());
    let points = chart_json["points"].as_array().expect("points array");
    assert!(!points.is_empty());
}

#[test]
fn trigger_weather_update_backfills_pending_farm_weather_fetch() {
    let client = ContractClient::from_env();
    let session_id = farmer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let farm_id = seed_farm_pending_weather(user_id);

    let path = format!("/api/v1/masters/farms/{farm_id}");
    let (pending_status, pending_body) =
        status_and_body(client.get(&path, Some(&session_id), &empty_headers()));
    assert_eq!(200, pending_status, "{pending_body}");
    let pending_json: serde_json::Value =
        serde_json::from_str(&pending_body).expect("farm show JSON");
    assert_eq!(
        "pending",
        pending_json["weather_data_status"].as_str().unwrap()
    );

    let (trigger_status, trigger_body) = status_and_body(client.post(
        "/api/v1/internal/jobs/trigger_weather_update",
        None,
        &scheduler_auth_headers(),
        None,
    ));
    assert_eq!(200, trigger_status, "{trigger_body}");

    let (show_status, show_body) =
        status_and_body(client.get(&path, Some(&session_id), &empty_headers()));
    assert_eq!(200, show_status, "{show_body}");
    let show_json: serde_json::Value = serde_json::from_str(&show_body).expect("farm show JSON");
    assert_eq!("fetching", show_json["weather_data_status"].as_str().unwrap());
    assert!(show_json["weather_data_total_years"].as_i64().unwrap() > 0);
}

#[test]
fn get_account_export_unauthenticated_returns_401() {
    let client = ContractClient::from_env();
    let (status, body) = status_and_body(client.get("/api/v1/account/export", None, &empty_headers()));
    assert_eq!(401, status, "{body}");
}

#[test]
fn get_account_export_authenticated_returns_user_data() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);

    let (status, body) =
        status_and_body(client.get("/api/v1/account/export", Some(&session_id), &empty_headers()));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("export JSON");
    assert_eq!(user_id, json["user"]["id"].as_i64().unwrap());
    assert!(json["exported_at"].as_str().is_some());
    assert!(json["farms"].is_array());
    assert!(json["crops"].is_array());
    assert!(json["cultivation_plans"].is_array());
}

#[test]
fn delete_account_without_confirm_returns_422() {
    let client = ContractClient::from_env();
    let session_id = researcher_session_id(&client);
    let (status, body) = status_and_body(client.delete_json(
        "/api/v1/account",
        Some(&session_id),
        &empty_headers(),
        serde_json::json!({ "confirm": false }),
    ));
    assert_eq!(422, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("delete JSON");
    assert_eq!("confirmation_required", json["error"].as_str().unwrap());
}

#[test]
fn delete_account_removes_access() {
    let client = ContractClient::from_env();
    let session_id = farmer_session_id(&client);

    let (delete_status, delete_body) = status_and_body(client.delete_json(
        "/api/v1/account",
        Some(&session_id),
        &empty_headers(),
        serde_json::json!({ "confirm": true }),
    ));
    assert_eq!(200, delete_status, "{delete_body}");

    let (me_status, me_body) =
        status_and_body(client.get("/api/v1/auth/me", Some(&session_id), &empty_headers()));
    assert_eq!(401, me_status, "{me_body}");
}

#[test]
fn get_private_plan_show_other_user_returns_not_found() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let seed = seed_work_record_plan(owner_id);

    let path = format!("/api/v1/plans/{}", seed.plan_id);
    let (owner_status, owner_body) =
        status_and_body(client.get(&path, Some(&owner_session), &empty_headers()));
    assert_eq!(200, owner_status, "{owner_body}");

    let other_session = farmer_session_id(&client);
    let (status, body) = status_and_body(client.get(&path, Some(&other_session), &empty_headers()));
    assert_cross_user_access_denied(status, &body);
}

#[test]
fn get_masters_farm_show_other_user_returns_forbidden_or_not_found() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let seed = seed_farm_temperature_chart_completed(owner_id);

    let path = format!("/api/v1/masters/farms/{}", seed.farm_id);
    let (owner_status, owner_body) =
        status_and_body(client.get(&path, Some(&owner_session), &empty_headers()));
    assert_eq!(200, owner_status, "{owner_body}");

    let other_session = farmer_session_id(&client);
    let (status, body) = status_and_body(client.get(&path, Some(&other_session), &empty_headers()));
    assert_cross_user_access_denied(status, &body);
}

#[test]
fn get_masters_crop_show_other_user_returns_forbidden_or_not_found() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let seed = seed_masters_crop(owner_id);

    let path = format!("/api/v1/masters/crops/{}", seed.crop_id);
    let (owner_status, owner_body) =
        status_and_body(client.get(&path, Some(&owner_session), &empty_headers()));
    assert_eq!(200, owner_status, "{owner_body}");

    let other_session = farmer_session_id(&client);
    let (status, body) = status_and_body(client.get(&path, Some(&other_session), &empty_headers()));
    assert_cross_user_access_denied(status, &body);
}

#[test]
fn get_work_records_list_other_user_returns_not_found() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let seed = seed_work_record_plan(owner_id);

    let list_path = format!("/api/v1/plans/{}/work_records", seed.plan_id);
    let (owner_status, owner_body) = status_and_body(
        client.get(&list_path, Some(&owner_session), &empty_headers()),
    );
    assert_eq!(200, owner_status, "{owner_body}");

    let other_session = farmer_session_id(&client);
    let (status, body) = status_and_body(client.get(&list_path, Some(&other_session), &empty_headers()));
    assert_cross_user_access_denied(status, &body);
}

#[test]
fn post_work_record_other_user_returns_not_found() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let seed = seed_work_record_plan(owner_id);

    let other_session = farmer_session_id(&client);
    let path = format!("/api/v1/plans/{}/work_records", seed.plan_id);
    let (status, body) = status_and_body(client.post(
        &path,
        Some(&other_session),
        &empty_headers(),
        Some(serde_json::json!({
            "work_record": {
                "task_schedule_item_id": seed.task_schedule_item_id,
                "actual_date": "2026-06-12",
                "notes": "cross-user create attempt"
            }
        })),
    ));
    assert_cross_user_access_denied(status, &body);
}

#[test]
fn patch_work_record_other_user_returns_not_found() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let seed = seed_work_record_plan(owner_id);

    let create_path = format!("/api/v1/plans/{}/work_records", seed.plan_id);
    let (create_status, create_body) = status_and_body(client.post(
        &create_path,
        Some(&owner_session),
        &empty_headers(),
        Some(serde_json::json!({
            "work_record": {
                "task_schedule_item_id": seed.task_schedule_item_id,
                "actual_date": "2026-06-12",
                "notes": "owner record for patch cross-user test"
            }
        })),
    ));
    assert_eq!(201, create_status, "{create_body}");
    let create_json: serde_json::Value =
        serde_json::from_str(&create_body).expect("create work_record JSON");
    let record_id = create_json["work_record"]["id"]
        .as_i64()
        .expect("work_record id");

    let other_session = farmer_session_id(&client);
    let patch_path = format!(
        "/api/v1/plans/{}/work_records/{}",
        seed.plan_id, record_id
    );
    let (status, body) = status_and_body(client.patch(
        &patch_path,
        Some(&other_session),
        &empty_headers(),
        Some(serde_json::json!({
            "work_record": { "notes": "cross-user patch attempt" }
        })),
    ));
    assert_cross_user_access_denied(status, &body);
}

#[test]
fn delete_work_record_other_user_returns_not_found() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let seed = seed_work_record_plan(owner_id);

    let create_path = format!("/api/v1/plans/{}/work_records", seed.plan_id);
    let (create_status, create_body) = status_and_body(client.post(
        &create_path,
        Some(&owner_session),
        &empty_headers(),
        Some(serde_json::json!({
            "work_record": {
                "task_schedule_item_id": seed.task_schedule_item_id,
                "actual_date": "2026-06-12",
                "notes": "owner record for delete cross-user test"
            }
        })),
    ));
    assert_eq!(201, create_status, "{create_body}");
    let create_json: serde_json::Value =
        serde_json::from_str(&create_body).expect("create work_record JSON");
    let record_id = create_json["work_record"]["id"]
        .as_i64()
        .expect("work_record id");

    let other_session = farmer_session_id(&client);
    let delete_path = format!(
        "/api/v1/plans/{}/work_records/{}",
        seed.plan_id, record_id
    );
    let (status, body) = status_and_body(client.delete(
        &delete_path,
        Some(&other_session),
        &empty_headers(),
    ));
    assert_cross_user_access_denied(status, &body);

    let (owner_list_status, owner_list_body) = status_and_body(
        client.get(&create_path, Some(&owner_session), &empty_headers()),
    );
    assert_eq!(200, owner_list_status, "{owner_list_body}");
    let list_json: serde_json::Value =
        serde_json::from_str(&owner_list_body).expect("work_records list JSON");
    let records = list_json["work_records"].as_array().expect("work_records");
    assert!(
        records.iter().any(|r| r["id"].as_i64() == Some(record_id)),
        "owner record must remain after cross-user delete attempt: {owner_list_body}"
    );
}

#[test]
fn get_organizations_list_returns_member_orgs() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        user_id,
        &format!("Contract Org {suffix}"),
        &format!("contract-org-{suffix}"),
        false,
    );

    let (status, body) =
        status_and_body(client.get("/api/v1/organizations", Some(&session_id), &empty_headers()));
    assert_eq!(200, status, "{body}");
    let orgs: Vec<serde_json::Value> = serde_json::from_str(&body).expect("organizations list JSON");
    let found = orgs
        .iter()
        .find(|o| o["id"].as_i64() == Some(seed.organization_id))
        .expect("seeded organization in list");
    assert_eq!(seed.name, found["name"].as_str().unwrap());
    assert_eq!(seed.slug, found["slug"].as_str().unwrap());
    assert_eq!(false, found["is_personal"].as_bool().unwrap());
}

#[test]
fn mock_login_ensures_personal_organization() {
    let client = ContractClient::from_env();
    let session_id = farmer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);

    let (status, body) =
        status_and_body(client.get("/api/v1/organizations", Some(&session_id), &empty_headers()));
    assert_eq!(200, status, "{body}");
    let orgs: Vec<serde_json::Value> = serde_json::from_str(&body).expect("organizations list JSON");
    let personal = orgs
        .iter()
        .find(|o| o["is_personal"].as_bool() == Some(true))
        .expect("personal organization in list after mock login");
    assert_eq!(
        format!("user-{user_id}"),
        personal["slug"].as_str().unwrap()
    );
    assert_eq!(true, personal["is_personal"].as_bool().unwrap());
}

#[test]
fn personal_org_backfill_sets_tier1_organization_id() {
    let client = ContractClient::from_env();
    let session_id = researcher_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let farm_id = seed_user_farm_without_organization(user_id);

    let org_id = run_personal_organization_ensure_for_user(user_id);

    let conn = rusqlite::Connection::open(
        std::env::var("AGRR_SQLITE_PATH").expect("AGRR_SQLITE_PATH"),
    )
    .expect("open contract sqlite");
    let farm_org: i64 = conn
        .query_row(
            "SELECT organization_id FROM farms WHERE id = ?1",
            rusqlite::params![farm_id],
            |row| row.get(0),
        )
        .expect("farm organization_id");
    assert_eq!(org_id, farm_org);

    let (status, body) =
        status_and_body(client.get("/api/v1/organizations", Some(&session_id), &empty_headers()));
    assert_eq!(200, status, "{body}");
    let orgs: Vec<serde_json::Value> = serde_json::from_str(&body).expect("organizations list JSON");
    assert!(
        orgs.iter().any(|o| o["id"].as_i64() == Some(org_id) && o["is_personal"].as_bool() == Some(true)),
        "personal org visible to user: {body}"
    );
}

#[test]
fn post_organizations_creates_org_and_membership() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let name = format!("Created Org {suffix}");
    let slug = format!("created-org-{suffix}");
    let payload = serde_json::json!({
        "organization": { "name": name, "slug": slug }
    });

    let (status, body) = status_and_body(
        client.post(
            "/api/v1/organizations",
            Some(&session_id),
            &empty_headers(),
            Some(payload),
        ),
    );
    assert_eq!(201, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("create organization JSON");
    assert_eq!(name, json["name"].as_str().unwrap());
    assert_eq!(slug, json["slug"].as_str().unwrap());
    assert_eq!(false, json["is_personal"].as_bool().unwrap());
    let org_id = json["id"].as_i64().expect("organization id");

    let path = format!("/api/v1/organizations/{org_id}");
    let (show_status, show_body) =
        status_and_body(client.get(&path, Some(&session_id), &empty_headers()));
    assert_eq!(200, show_status, "{show_body}");
}

#[test]
fn patch_organizations_updates_org() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        user_id,
        &format!("Patch Org {suffix}"),
        &format!("patch-org-{suffix}"),
        false,
    );
    let updated_name = format!("Updated Org {suffix}");
    let updated_slug = format!("updated-org-{suffix}");
    let path = format!("/api/v1/organizations/{}", seed.organization_id);
    let payload = serde_json::json!({
        "organization": { "name": updated_name, "slug": updated_slug }
    });

    let (status, body) = status_and_body(
        client.patch(&path, Some(&session_id), &empty_headers(), Some(payload)),
    );
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("update organization JSON");
    assert_eq!(updated_name, json["name"].as_str().unwrap());
    assert_eq!(updated_slug, json["slug"].as_str().unwrap());
}

#[test]
fn delete_organizations_deletes_team_org() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        user_id,
        &format!("Delete Org {suffix}"),
        &format!("delete-org-{suffix}"),
        false,
    );
    let path = format!("/api/v1/organizations/{}", seed.organization_id);

    let (status, body) =
        status_and_body(client.delete(&path, Some(&session_id), &empty_headers()));
    assert_eq!(204, status, "{body}");

    let (show_status, show_body) =
        status_and_body(client.get(&path, Some(&session_id), &empty_headers()));
    assert_eq!(404, show_status, "{show_body}");
}

#[test]
fn delete_organizations_personal_org_forbidden() {
    let client = ContractClient::from_env();
    let session_id = developer_session_id(&client);
    let user_id = user_id_for_session(&client, &session_id);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        user_id,
        &format!("Personal Org {suffix}"),
        &format!("personal-org-{suffix}"),
        true,
    );
    let path = format!("/api/v1/organizations/{}", seed.organization_id);

    let (status, body) =
        status_and_body(client.delete(&path, Some(&session_id), &empty_headers()));
    assert_eq!(422, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("personal delete JSON");
    assert!(json.get("error").is_some(), "{body}");
}

#[test]
fn get_organizations_cross_user_denied() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let other_session = farmer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        owner_id,
        &format!("Private Org {suffix}"),
        &format!("private-org-{suffix}"),
        false,
    );
    let path = format!("/api/v1/organizations/{}", seed.organization_id);

    let (status, body) = status_and_body(client.get(&path, Some(&other_session), &empty_headers()));
    assert_cross_user_access_denied(status, &body);
}

#[test]
fn get_organization_memberships_lists_members() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let member_session = farmer_session_id(&client);
    let member_id = user_id_for_session(&client, &member_session);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        owner_id,
        &format!("Membership List Org {suffix}"),
        &format!("membership-list-org-{suffix}"),
        false,
    );
    seed_organization_membership(seed.organization_id, member_id, "member");

    let path = format!("/api/v1/organizations/{}/memberships", seed.organization_id);
    let (status, body) =
        status_and_body(client.get(&path, Some(&owner_session), &empty_headers()));
    assert_eq!(200, status, "{body}");
    let memberships: Vec<serde_json::Value> =
        serde_json::from_str(&body).expect("memberships list JSON");
    assert!(
        memberships.iter().any(|m| m["user_id"].as_i64() == Some(owner_id)),
        "owner membership missing: {body}"
    );
    assert!(
        memberships.iter().any(|m| m["user_id"].as_i64() == Some(member_id)),
        "member membership missing: {body}"
    );
}

#[test]
fn post_organization_memberships_adds_member() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let invitee_session = researcher_session_id(&client);
    let invitee_id = user_id_for_session(&client, &invitee_session);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        owner_id,
        &format!("Membership Add Org {suffix}"),
        &format!("membership-add-org-{suffix}"),
        false,
    );

    let path = format!("/api/v1/organizations/{}/memberships", seed.organization_id);
    let payload = serde_json::json!({
        "membership": { "user_id": invitee_id, "role": "admin" }
    });
    let (status, body) = status_and_body(
        client.post(&path, Some(&owner_session), &empty_headers(), Some(payload)),
    );
    assert_eq!(201, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("create membership JSON");
    assert_eq!(invitee_id, json["user_id"].as_i64().unwrap());
    assert_eq!("admin", json["role"].as_str().unwrap());
}

#[test]
fn patch_organization_memberships_updates_role() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let member_session = farmer_session_id(&client);
    let member_id = user_id_for_session(&client, &member_session);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        owner_id,
        &format!("Membership Patch Org {suffix}"),
        &format!("membership-patch-org-{suffix}"),
        false,
    );
    seed_organization_membership(seed.organization_id, member_id, "member");

    let path = format!(
        "/api/v1/organizations/{}/memberships/{}",
        seed.organization_id,
        member_id
    );
    let payload = serde_json::json!({ "membership": { "role": "admin" } });
    let (status, body) = status_and_body(
        client.patch(&path, Some(&owner_session), &empty_headers(), Some(payload)),
    );
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("update membership JSON");
    assert_eq!("admin", json["role"].as_str().unwrap());
}

#[test]
fn delete_organization_memberships_removes_member() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let member_session = farmer_session_id(&client);
    let member_id = user_id_for_session(&client, &member_session);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        owner_id,
        &format!("Membership Delete Org {suffix}"),
        &format!("membership-delete-org-{suffix}"),
        false,
    );
    seed_organization_membership(seed.organization_id, member_id, "member");

    let path = format!(
        "/api/v1/organizations/{}/memberships/{}",
        seed.organization_id,
        member_id
    );
    let (status, body) =
        status_and_body(client.delete(&path, Some(&owner_session), &empty_headers()));
    assert_eq!(204, status, "{body}");

    let list_path = format!("/api/v1/organizations/{}/memberships", seed.organization_id);
    let (list_status, list_body) =
        status_and_body(client.get(&list_path, Some(&owner_session), &empty_headers()));
    assert_eq!(200, list_status, "{list_body}");
    let memberships: Vec<serde_json::Value> =
        serde_json::from_str(&list_body).expect("memberships after delete JSON");
    assert!(
        !memberships.iter().any(|m| m["user_id"].as_i64() == Some(member_id)),
        "member should be removed: {list_body}"
    );
}

#[test]
fn post_organization_memberships_member_role_forbidden() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let member_session = farmer_session_id(&client);
    let member_id = user_id_for_session(&client, &member_session);
    let invitee_session = researcher_session_id(&client);
    let invitee_id = user_id_for_session(&client, &invitee_session);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        owner_id,
        &format!("Membership Member Forbidden {suffix}"),
        &format!("membership-member-forbidden-{suffix}"),
        false,
    );
    seed_organization_membership(seed.organization_id, member_id, "member");

    let path = format!("/api/v1/organizations/{}/memberships", seed.organization_id);
    let payload = serde_json::json!({
        "membership": { "user_id": invitee_id, "role": "member" }
    });
    let (status, body) = status_and_body(
        client.post(&path, Some(&member_session), &empty_headers(), Some(payload)),
    );
    assert_eq!(403, status, "{body}");
}

#[test]
fn delete_organization_memberships_admin_cannot_remove_owner() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let admin_session = farmer_session_id(&client);
    let admin_id = user_id_for_session(&client, &admin_session);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        owner_id,
        &format!("Membership Admin Owner {suffix}"),
        &format!("membership-admin-owner-{suffix}"),
        false,
    );
    seed_organization_membership(seed.organization_id, admin_id, "admin");

    let path = format!(
        "/api/v1/organizations/{}/memberships/{}",
        seed.organization_id,
        owner_id
    );
    let (status, body) =
        status_and_body(client.delete(&path, Some(&admin_session), &empty_headers()));
    assert_eq!(403, status, "{body}");
}

#[test]
fn get_organization_memberships_cross_user_denied() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let other_session = researcher_session_id(&client);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        owner_id,
        &format!("Membership Private {suffix}"),
        &format!("membership-private-{suffix}"),
        false,
    );
    let path = format!("/api/v1/organizations/{}/memberships", seed.organization_id);

    let (status, body) =
        status_and_body(client.get(&path, Some(&other_session), &empty_headers()));
    assert_cross_user_access_denied(status, &body);
}

#[test]
fn org_member_can_view_team_farm() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let member_session = farmer_session_id(&client);
    let member_id = user_id_for_session(&client, &member_session);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        owner_id,
        &format!("Team Farm Org {suffix}"),
        &format!("team-farm-org-{suffix}"),
        false,
    );
    seed_organization_membership(seed.organization_id, member_id, "member");
    let farm_id = seed_org_scoped_farm(seed.organization_id, owner_id);

    let path = format!("/api/v1/masters/farms/{farm_id}");
    let (owner_status, owner_body) =
        status_and_body(client.get(&path, Some(&owner_session), &empty_headers()));
    assert_eq!(200, owner_status, "{owner_body}");

    let (member_status, member_body) =
        status_and_body(client.get(&path, Some(&member_session), &empty_headers()));
    assert_eq!(200, member_status, "{member_body}");
}

#[test]
fn org_member_can_update_team_farm() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let member_session = farmer_session_id(&client);
    let member_id = user_id_for_session(&client, &member_session);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        owner_id,
        &format!("Team Farm Update Org {suffix}"),
        &format!("team-farm-update-org-{suffix}"),
        false,
    );
    seed_organization_membership(seed.organization_id, member_id, "member");
    let farm_id = seed_org_scoped_farm(seed.organization_id, owner_id);

    let path = format!("/api/v1/masters/farms/{farm_id}");
    let payload = serde_json::json!({
        "farm": {
            "name": format!("Updated by member {suffix}"),
            "region": "jp",
            "latitude": 35.0,
            "longitude": 139.0
        }
    });
    let (status, body) = status_and_body(
        client.patch(&path, Some(&member_session), &empty_headers(), Some(payload)),
    );
    assert_eq!(200, status, "{body}");
}

#[test]
fn org_non_member_denied_team_farm() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let other_session = researcher_session_id(&client);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        owner_id,
        &format!("Team Farm Deny Org {suffix}"),
        &format!("team-farm-deny-org-{suffix}"),
        false,
    );
    let farm_id = seed_org_scoped_farm(seed.organization_id, owner_id);

    let path = format!("/api/v1/masters/farms/{farm_id}");
    let (status, body) =
        status_and_body(client.get(&path, Some(&other_session), &empty_headers()));
    assert_cross_user_access_denied(status, &body);
}

#[test]
fn org_member_can_view_team_crop() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let member_session = farmer_session_id(&client);
    let member_id = user_id_for_session(&client, &member_session);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        owner_id,
        &format!("Team Crop Org {suffix}"),
        &format!("team-crop-org-{suffix}"),
        false,
    );
    seed_organization_membership(seed.organization_id, member_id, "member");
    let crop_id = seed_org_scoped_crop(seed.organization_id, owner_id);

    let path = format!("/api/v1/masters/crops/{crop_id}");
    let (member_status, member_body) =
        status_and_body(client.get(&path, Some(&member_session), &empty_headers()));
    assert_eq!(200, member_status, "{member_body}");
}

#[test]
fn org_member_can_update_team_crop() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let member_session = farmer_session_id(&client);
    let member_id = user_id_for_session(&client, &member_session);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        owner_id,
        &format!("Team Crop Update Org {suffix}"),
        &format!("team-crop-update-org-{suffix}"),
        false,
    );
    seed_organization_membership(seed.organization_id, member_id, "member");
    let crop_id = seed_org_scoped_crop(seed.organization_id, owner_id);

    let path = format!("/api/v1/masters/crops/{crop_id}");
    let payload = serde_json::json!({
        "crop": { "name": format!("Updated Crop {suffix}") }
    });
    let (status, body) = status_and_body(
        client.patch(&path, Some(&member_session), &empty_headers(), Some(payload)),
    );
    assert_eq!(200, status, "{body}");
}

#[test]
fn org_non_member_denied_team_crop() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let other_session = researcher_session_id(&client);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        owner_id,
        &format!("Team Crop Deny Org {suffix}"),
        &format!("team-crop-deny-org-{suffix}"),
        false,
    );
    let crop_id = seed_org_scoped_crop(seed.organization_id, owner_id);

    let path = format!("/api/v1/masters/crops/{crop_id}");
    let (status, body) =
        status_and_body(client.get(&path, Some(&other_session), &empty_headers()));
    assert_cross_user_access_denied(status, &body);
}

#[test]
fn org_member_can_view_team_plan() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let member_session = farmer_session_id(&client);
    let member_id = user_id_for_session(&client, &member_session);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        owner_id,
        &format!("Team Plan Org {suffix}"),
        &format!("team-plan-org-{suffix}"),
        false,
    );
    seed_organization_membership(seed.organization_id, member_id, "member");
    let plan_id = seed_org_scoped_plan(seed.organization_id, owner_id);

    let path = format!("/api/v1/plans/{plan_id}");
    let (member_status, member_body) =
        status_and_body(client.get(&path, Some(&member_session), &empty_headers()));
    assert_eq!(200, member_status, "{member_body}");
}

#[test]
fn org_non_member_denied_team_plan() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let other_session = researcher_session_id(&client);
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seed = seed_user_organization(
        owner_id,
        &format!("Team Plan Deny Org {suffix}"),
        &format!("team-plan-deny-org-{suffix}"),
        false,
    );
    let plan_id = seed_org_scoped_plan(seed.organization_id, owner_id);

    let path = format!("/api/v1/plans/{plan_id}");
    let (status, body) =
        status_and_body(client.get(&path, Some(&other_session), &empty_headers()));
    assert_cross_user_access_denied(status, &body);
}

#[test]
fn cable_rejects_cross_user_private_plans_optimization_channel() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let attacker_session = farmer_session_id(&client);
    let seed = seed_work_record_plan(owner_id);
    let identifier = serde_json::json!({
        "channel": "PlansOptimizationChannel",
        "cultivation_plan_id": seed.plan_id
    });

    tokio::runtime::Runtime::new()
        .expect("tokio runtime")
        .block_on(async {
            let rejected = cable_subscribe_frame_type(Some(&attacker_session), identifier.clone())
                .await;
            assert_eq!("reject_subscription", rejected.frame_type);

            let confirmed = cable_subscribe_frame_type(Some(&owner_session), identifier).await;
            assert_eq!("confirm_subscription", confirmed.frame_type);
        });
}

#[test]
fn cable_rejects_cross_user_non_reference_farm_channel() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let attacker_session = farmer_session_id(&client);
    let seed = seed_work_record_plan(owner_id);
    let identifier = serde_json::json!({
        "channel": "FarmChannel",
        "farm_id": seed.farm_id
    });

    tokio::runtime::Runtime::new()
        .expect("tokio runtime")
        .block_on(async {
            let rejected = cable_subscribe_frame_type(Some(&attacker_session), identifier.clone())
                .await;
            assert_eq!("reject_subscription", rejected.frame_type);

            let confirmed = cable_subscribe_frame_type(Some(&owner_session), identifier).await;
            assert_eq!("confirm_subscription", confirmed.frame_type);
        });
}

#[test]
fn cable_allows_unauthenticated_public_optimization_channel() {
    let client = ContractClient::from_env();
    let owner_session = developer_session_id(&client);
    let owner_id = user_id_for_session(&client, &owner_session);
    let plan_id = seed_public_cultivation_plan(owner_id);
    let identifier = serde_json::json!({
        "channel": "OptimizationChannel",
        "cultivation_plan_id": plan_id
    });

    tokio::runtime::Runtime::new()
        .expect("tokio runtime")
        .block_on(async {
            let confirmed = cable_subscribe_frame_type(None, identifier).await;
            assert_eq!("confirm_subscription", confirmed.frame_type);
        });
}

fn contact_message_payload(email_suffix: u128) -> serde_json::Value {
    serde_json::json!({
        "email": format!("contact-contract-{email_suffix}@example.com"),
        "message": "contract test message"
    })
}

#[test]
fn post_contact_message_creates_queued_record() {
    let client = ContractClient::from_env();
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let mut headers = empty_headers();
    headers.insert(
        "x-forwarded-for".to_string(),
        format!("203.0.113.{suffix}"),
    );
    let (status, body) = status_and_body(client.post(
        "/api/v1/contact_messages",
        None,
        &headers,
        Some(contact_message_payload(suffix)),
    ));
    assert_eq!(201, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("contact message JSON");
    assert_eq!(Some("queued"), json["status"].as_str());
    assert!(json["id"].as_i64().is_some());
}

#[test]
fn post_contact_message_returns_429_when_rate_limit_exceeded() {
    let client = ContractClient::from_env();
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let mut headers = empty_headers();
    let ip_octet = (suffix % 200) as u8 + 1;
    headers.insert(
        "x-forwarded-for".to_string(),
        format!("203.0.113.{ip_octet}"),
    );
    let payload = contact_message_payload(suffix);
    for i in 0..10 {
        let (status, body) = status_and_body(client.post(
            "/api/v1/contact_messages",
            None,
            &headers,
            Some(payload.clone()),
        ));
        assert_eq!(201, status, "request {i}: {body}");
    }
    let (status, body) = status_and_body(client.post(
        "/api/v1/contact_messages",
        None,
        &headers,
        Some(payload),
    ));
    assert_eq!(429, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("rate limit JSON");
    assert_eq!(Some("rate_limit"), json["error"].as_str());
}

#[test]
fn post_contact_message_returns_422_when_recaptcha_fails() {
    let secret = std::env::var("RECAPTCHA_SECRET_KEY").unwrap_or_default();
    if secret.trim().is_empty() {
        eprintln!("SKIP post_contact_message_returns_422_when_recaptcha_fails: RECAPTCHA_SECRET_KEY unset");
        return;
    }
    let client = ContractClient::from_env();
    let suffix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let mut headers = empty_headers();
    headers.insert(
        "x-forwarded-for".to_string(),
        format!("203.0.113.{suffix}"),
    );
    let (status, body) = status_and_body(client.post(
        "/api/v1/contact_messages",
        None,
        &headers,
        Some(serde_json::json!({
            "email": format!("recaptcha-contract-{suffix}@example.com"),
            "message": "contract recaptcha failure",
            "recaptcha_token": "invalid-token-for-contract-test"
        })),
    ));
    assert_eq!(422, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("recaptcha failure JSON");
    assert!(json["error"].as_str().unwrap_or("").contains("reCAPTCHA"));
}

#[test]
fn logout_revokes_only_current_session_leaves_other_devices_authenticated() {
    let client = ContractClient::from_env();
    let session_a = developer_session_id(&client);
    let session_b = developer_session_id(&client);
    assert_eq!(
        user_id_for_session(&client, &session_a),
        user_id_for_session(&client, &session_b),
        "both sessions must belong to the same developer user"
    );

    let (logout_status, logout_body) = status_and_body(
        client.delete("/api/v1/auth/logout", Some(&session_a), &empty_headers()),
    );
    assert_eq!(200, logout_status, "{logout_body}");

    let (status_a, body_a) =
        status_and_body(client.get("/api/v1/auth/me", Some(&session_a), &empty_headers()));
    assert_eq!(401, status_a, "logged-out session must be unauthorized: {body_a}");

    let (status_b, body_b) =
        status_and_body(client.get("/api/v1/auth/me", Some(&session_b), &empty_headers()));
    assert_eq!(
        200,
        status_b,
        "other device session must remain valid after single-device logout: {body_b}"
    );
}

fn contract_backdoor_token() -> String {
    std::env::var("AGRR_BACKDOOR_TOKEN").unwrap_or_else(|_| "contract-token".into())
}

fn backdoor_headers() -> std::collections::HashMap<String, String> {
    let mut headers = empty_headers();
    headers.insert(
        "X-Backdoor-Token".to_string(),
        contract_backdoor_token(),
    );
    headers
}

#[test]
fn get_backdoor_health_requires_token() {
    let client = ContractClient::from_env();
    let (status, body) = status_and_body(client.get("/api/v1/backdoor/health", None, &empty_headers()));
    assert_eq!(401, status, "{body}");
}

#[test]
fn get_backdoor_health_succeeds_with_backdoor_token() {
    let client = ContractClient::from_env();
    let (status, body) = status_and_body(client.get(
        "/api/v1/backdoor/health",
        None,
        &backdoor_headers(),
    ));
    assert_eq!(200, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("backdoor health JSON");
    assert_eq!(Some("ok"), json["status"].as_str());
}

#[test]
fn post_backdoor_db_clear_requires_confirmation_token() {
    let client = ContractClient::from_env();
    let (status, body) = status_and_body(client.post(
        "/api/v1/backdoor/db/clear",
        None,
        &backdoor_headers(),
        Some(serde_json::json!({})),
    ));
    assert_eq!(400, status, "{body}");
    let json: serde_json::Value = serde_json::from_str(&body).expect("db clear JSON");
    assert_eq!(Some(false), json["success"].as_bool());
}
