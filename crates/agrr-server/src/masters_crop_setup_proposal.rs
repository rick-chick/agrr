//! `POST /api/v1/masters/crops/{crop_id}/setup_proposal?mode=dry_run|apply`

use crate::masters_auth::MastersUserId;
use crate::masters_crop_context::{auth_user, internal_error};
use crate::state::AppState;
use agrr_adapters_sqlite::{
    AgriculturalTaskSqliteGateway, CropMastersTaskScheduleBlueprintSqliteGateway,
    CropSetupProposalSqliteGateway, CropSqliteGateway, UserLookupSqliteGateway,
};
use agrr_domain::crop::dtos::{
    CropSetupProposalApplyResult, CropSetupProposalInput, CropSetupProposalMode,
    CropSetupProposalValidationError,
};
use agrr_domain::crop::interactors::crop_setup_proposal_interactor::CropSetupProposalInteractor;
use agrr_domain::crop::ports::CropSetupProposalOutputPort;
use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    routing::post,
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new().route(
        "/api/v1/masters/crops/{crop_id}/setup_proposal",
        post(setup_proposal),
    )
}

#[derive(Deserialize)]
struct SetupProposalQuery {
    mode: String,
}

async fn setup_proposal(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(crop_id): Path<i64>,
    Query(query): Query<SetupProposalQuery>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let mode = match query.mode.as_str() {
        "dry_run" => CropSetupProposalMode::DryRun,
        "apply" => CropSetupProposalMode::Apply,
        _ => {
            return Err((
                StatusCode::UNPROCESSABLE_ENTITY,
                Json(json!({
                    "error": "mode must be dry_run or apply"
                })),
            ));
        }
    };

    let user_id = auth_user(auth);
    let pool = state.sqlite.clone();
    let crop_gateway = CropSqliteGateway::new(pool.clone());
    let blueprint_gateway = CropMastersTaskScheduleBlueprintSqliteGateway::new(pool.clone());
    let agricultural_task_gateway = AgriculturalTaskSqliteGateway::new(pool.clone());
    let proposal_gateway = CropSetupProposalSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);

    struct Port {
        mode: CropSetupProposalMode,
        resp: Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>,
    }

    impl CropSetupProposalOutputPort for Port {
        fn on_dry_run_success(&mut self, normalized: Value) {
            self.resp = Some(Ok((
                StatusCode::OK,
                Json(json!({
                    "mode": "dry_run",
                    "valid": true,
                    "normalized": normalized,
                })),
            )));
        }

        fn on_validation_failure(&mut self, errors: Vec<CropSetupProposalValidationError>) {
            let mode_label = match self.mode {
                CropSetupProposalMode::DryRun => "dry_run",
                CropSetupProposalMode::Apply => "apply",
            };
            self.resp = Some(Ok((
                StatusCode::OK,
                Json(json!({
                    "mode": mode_label,
                    "valid": false,
                    "errors": errors_to_json(&errors),
                })),
            )));
        }

        fn on_apply_success(&mut self, result: CropSetupProposalApplyResult, normalized: Value) {
            self.resp = Some(Ok((
                StatusCode::CREATED,
                Json(json!({
                    "mode": "apply",
                    "valid": true,
                    "normalized": normalized,
                    "result": {
                        "stage_ids": result.stage_ids,
                        "agricultural_task_ids": result.agricultural_task_ids,
                        "blueprint_ids": result.blueprint_ids,
                    }
                })),
            )));
        }

        fn on_crop_not_found(&mut self) {
            self.resp = Some(Err((
                StatusCode::NOT_FOUND,
                Json(json!({ "error": "crop not found" })),
            )));
        }
    }

    let mut port = Port {
        mode,
        resp: None,
    };
    let mut interactor = CropSetupProposalInteractor::new(
        &mut port,
        &crop_gateway,
        &blueprint_gateway,
        &agricultural_task_gateway,
        &proposal_gateway,
        &user_lookup,
    );

    interactor
        .call(CropSetupProposalInput::new(user_id, crop_id, mode, body))
        .map_err(|_| internal_error())?;

    port.resp.unwrap_or(Err(internal_error()))
}

fn errors_to_json(errors: &[CropSetupProposalValidationError]) -> Vec<Value> {
    errors
        .iter()
        .map(|error| {
            json!({
                "path": error.path,
                "message": error.message,
            })
        })
        .collect()
}
