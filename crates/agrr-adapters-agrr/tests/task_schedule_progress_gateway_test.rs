//! Progress gateway parity for task schedule generation.

use std::sync::Arc;

use agrr_adapters_agrr::{FieldCultivationClimateAgrrGateway, TaskScheduleProgressAgrrGateway};
use agrr_domain::agricultural_task::gateways::{
    ProgressGateway, TaskScheduleCrop, TaskScheduleGenerationReadGateway,
};
use serde_json::json;

struct StubReadGateway;

impl TaskScheduleGenerationReadGateway for StubReadGateway {
    fn find_plan_row(
        &self,
        _: i64,
    ) -> Result<
        agrr_domain::agricultural_task::gateways::TaskSchedulePlanRow,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        unimplemented!()
    }

    fn list_field_cultivation_rows(
        &self,
        _: i64,
    ) -> Result<
        Vec<agrr_domain::agricultural_task::gateways::TaskScheduleFieldCultivationRow>,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        unimplemented!()
    }

    fn find_crop_row(
        &self,
        _: i64,
    ) -> Result<
        agrr_domain::agricultural_task::gateways::TaskScheduleCropRow,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        unimplemented!()
    }

    fn list_crop_task_schedule_blueprint_rows(
        &self,
        _: i64,
    ) -> Result<
        Vec<agrr_domain::agricultural_task::gateways::TaskScheduleBlueprintRow>,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        unimplemented!()
    }

    fn build_crop_agrr_requirement(
        &self,
        _: i64,
    ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
        Ok(json!({
            "crop": { "crop_id": "1", "name": "stub" },
            "stage_requirements": []
        }))
    }
}

#[test]
fn progress_gateway_reports_daemon_unavailable_when_daemon_not_running() {
    let socket_path = "/tmp/agrr_task_schedule_progress_missing.sock";
    let prev_retries = std::env::var("AGRR_DAEMON_REQUEST_RETRIES").ok();
    let prev_socket = std::env::var("AGRR_SOCKET_PATH").ok();
    std::env::set_var("AGRR_DAEMON_REQUEST_RETRIES", "1");
    std::env::set_var("AGRR_SOCKET_PATH", socket_path);
    let climate = FieldCultivationClimateAgrrGateway::from_env();
    let gateway = TaskScheduleProgressAgrrGateway::new(
        climate,
        Arc::new(StubReadGateway) as Arc<dyn TaskScheduleGenerationReadGateway>,
    );
    let crop = TaskScheduleCrop {
        id: 1,
        name: "stub".into(),
        crop_task_schedule_blueprints: vec![],
    };
    let err = gateway
        .calculate_progress(
            &crop,
            Some(time::macros::date!(2026 - 04 - 01)),
            &json!({ "data": [] }),
        )
        .expect_err("daemon unavailable");
    assert_eq!(
        agrr_domain::agricultural_task::task_schedule_sync_error_i18n_key(err.as_ref()),
        agrr_domain::agricultural_task::task_schedule_sync_error_keys::AGRR_UNAVAILABLE.to_string()
    );
    restore_env("AGRR_DAEMON_REQUEST_RETRIES", prev_retries);
    restore_env("AGRR_SOCKET_PATH", prev_socket);
}

fn restore_env(key: &str, prev: Option<String>) {
    match prev {
        Some(value) => std::env::set_var(key, value),
        None => std::env::remove_var(key),
    }
}

#[test]
fn progress_gateway_requires_start_date() {
    let climate = FieldCultivationClimateAgrrGateway::from_env();
    let gateway = TaskScheduleProgressAgrrGateway::new(
        climate,
        Arc::new(StubReadGateway) as Arc<dyn TaskScheduleGenerationReadGateway>,
    );
    let crop = TaskScheduleCrop {
        id: 1,
        name: "stub".into(),
        crop_task_schedule_blueprints: vec![],
    };
    let err = gateway
        .calculate_progress(&crop, None, &json!({ "data": [] }))
        .expect_err("missing start date");
    assert_eq!(
        agrr_domain::agricultural_task::task_schedule_sync_error_i18n_key(err.as_ref()),
        agrr_domain::agricultural_task::task_schedule_sync_error_keys::MISSING_START_DATE.to_string()
    );
}
