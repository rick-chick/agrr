//! `POST /api/v1/masters/crops/{crop_id}/setup_proposal?mode=dry_run|apply`

use crate::masters_auth::MastersUserId;
use crate::masters_crop_context::{auth_user, internal_error};
use crate::state::AppState;
use agrr_adapters_sqlite::{
    AgriculturalTaskSqliteGateway, CropMastersTaskScheduleBlueprintSqliteGateway,
    CropSetupProposalSqliteGateway, CropSqliteGateway, UserLookupSqliteGateway,
    UserOrganizationScopeSqliteGateway,
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
    let mode = parse_setup_proposal_mode(&query.mode)?;

    let user_id = auth_user(auth);
    let pool = state.sqlite.clone();
    let crop_gateway = CropSqliteGateway::new(pool.clone());
    let blueprint_gateway = CropMastersTaskScheduleBlueprintSqliteGateway::new(pool.clone());
    let agricultural_task_gateway = AgriculturalTaskSqliteGateway::new(pool.clone());
    let proposal_gateway = CropSetupProposalSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool.clone());
    let scope_gateway = UserOrganizationScopeSqliteGateway::new(pool);

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
            let (status, body) = setup_proposal_crop_not_found();
            self.resp = Some(Err((status, Json(body))));
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
        &scope_gateway,
    );

    interactor
        .call(CropSetupProposalInput::new(user_id, crop_id, mode, body))
        .map_err(|_| internal_error())?;

    port.resp.unwrap_or(Err(internal_error()))
}

fn parse_setup_proposal_mode(
    mode: &str,
) -> Result<CropSetupProposalMode, (StatusCode, Json<Value>)> {
    match mode {
        "dry_run" => Ok(CropSetupProposalMode::DryRun),
        "apply" => Ok(CropSetupProposalMode::Apply),
        _ => Err(setup_proposal_invalid_mode()),
    }
}

fn setup_proposal_invalid_mode() -> (StatusCode, Json<Value>) {
    let (status, body) = (
        StatusCode::UNPROCESSABLE_ENTITY,
        json!({"errors": ["mode must be dry_run or apply"]}),
    );
    (status, Json(body))
}

fn setup_proposal_crop_not_found() -> (StatusCode, Value) {
    (
        StatusCode::NOT_FOUND,
        json!({"errors": ["crop not found"]}),
    )
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_setup_proposal_mode_accepts_dry_run_and_apply() {
        assert_eq!(
            parse_setup_proposal_mode("dry_run").unwrap(),
            CropSetupProposalMode::DryRun
        );
        assert_eq!(
            parse_setup_proposal_mode("apply").unwrap(),
            CropSetupProposalMode::Apply
        );
    }

    #[test]
    fn parse_setup_proposal_mode_rejects_unknown_with_422() {
        let err = parse_setup_proposal_mode("preview").unwrap_err();
        assert_eq!(err.0, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(err.1.0["errors"][0], "mode must be dry_run or apply");
    }

    #[test]
    fn setup_proposal_crop_not_found_maps_to_404() {
        let (status, body) = setup_proposal_crop_not_found();
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert_eq!(body["errors"][0], "crop not found");
    }

    #[test]
    fn errors_to_json_maps_path_and_message() {
        let errors = vec![
            CropSetupProposalValidationError {
                path: "stages[0].name".into(),
                message: "required".into(),
            },
            CropSetupProposalValidationError {
                path: "blueprints".into(),
                message: "empty".into(),
            },
        ];
        let json = errors_to_json(&errors);
        assert_eq!(json.len(), 2);
        assert_eq!(json[0]["path"], "stages[0].name");
        assert_eq!(json[0]["message"], "required");
        assert_eq!(json[1]["path"], "blueprints");
    }
}