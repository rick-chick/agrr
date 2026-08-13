//! `GET /api/v1/plans/:id/variance_learning` — persisted variance learning snapshot.

use crate::adapters::{NoopLogger, PassthroughTranslator};
use crate::plan_vs_actual_json::summary_to_json_body;
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::{
    CultivationPlanPrivateSnapshotReadSqliteGateway, CultivationPlanSqliteGateway,
    PlanVarianceLearningSqliteGateway, UserLookupSqliteGateway, UserOrganizationScopeSqliteGateway,
};
use agrr_domain::cultivation_plan::dtos::PlanVarianceLearningSnapshotRead;
use agrr_domain::cultivation_plan::gateways::{
    CultivationPlanGateway, PlanVarianceLearningGateway,
};
use agrr_domain::cultivation_plan::interactors::{
    PlanVarianceCarryoverInput, PlanVarianceCarryoverInteractor, PlanVarianceLearningReadInteractor,
};
use agrr_domain::cultivation_plan::ports::PlanVarianceLearningReadOutputPort;
use agrr_domain::shared::dtos::Error;
use agrr_domain::shared::exceptions::RecordNotFoundError;
use axum::{
    extract::{Path, State},
    routing::get,
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new().route(
        "/api/v1/plans/{id}/variance_learning",
        get(show_variance_learning).post(import_variance_learning),
    )
}

struct VarianceLearningPresenter {
    body: Option<VarianceLearningOutcome>,
}

enum VarianceLearningOutcome {
    Success(PlanVarianceLearningSnapshotRead),
    NotFound,
}

impl PlanVarianceLearningReadOutputPort for VarianceLearningPresenter {
    fn on_success(&mut self, dto: PlanVarianceLearningSnapshotRead) {
        self.body = Some(VarianceLearningOutcome::Success(dto));
    }

    fn on_failure(&mut self, _error: Error) {
        self.body = Some(VarianceLearningOutcome::NotFound);
    }
}

async fn show_variance_learning(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(plan_id): Path<i64>,
) -> Result<Json<Value>, (axum::http::StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(json!({"errors": ["unauthorized"]})),
        )
    })?;

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let variance_gateway = PlanVarianceLearningSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool.clone());
    let scope_gateway = UserOrganizationScopeSqliteGateway::new(pool);

    let mut presenter = VarianceLearningPresenter { body: None };
    let translator = PassthroughTranslator;
    let logger = NoopLogger;

    let mut interactor = PlanVarianceLearningReadInteractor::new(
        &mut presenter,
        user_id,
        plan_id,
        &plan_gateway,
        &variance_gateway,
        &translator,
        &logger,
        &user_lookup,
        &scope_gateway,
    );

    match interactor.call() {
        Ok(()) => match presenter.body {
            Some(VarianceLearningOutcome::Success(snapshot)) => {
                let summary_body = summary_to_json_body(snapshot.summary);
                Ok(Json(json!({
                    "plan_id": snapshot.plan_id,
                    "source_plan_id": snapshot.source_plan_id,
                    "summary": summary_body,
                })))
            }
            Some(VarianceLearningOutcome::NotFound) | None => Err((
                axum::http::StatusCode::NOT_FOUND,
                Json(json!({"errors": ["not_found"]})),
            )),
        },
        Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => Err((
            axum::http::StatusCode::NOT_FOUND,
            Json(json!({"errors": ["not_found"]})),
        )),
        Err(err) => {
            tracing::error!("variance_learning read failed: {err}");
            Err((
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"errors": ["internal_error"]})),
            ))
        }
    }
}

#[derive(serde::Deserialize)]
struct ImportVarianceLearningBody {
    source_plan_id: i64,
}

async fn import_variance_learning(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(plan_id): Path<i64>,
    Json(body): Json<ImportVarianceLearningBody>,
) -> Result<Json<Value>, (axum::http::StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(json!({"errors": ["unauthorized"]})),
        )
    })?;

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let target_plan = plan_gateway.find_by_id(plan_id).map_err(|err| {
        if err.downcast_ref::<RecordNotFoundError>().is_some() {
            (
                axum::http::StatusCode::NOT_FOUND,
                Json(json!({"errors": ["not_found"]})),
            )
        } else {
            tracing::error!("variance_learning import plan lookup failed: {err}");
            (
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"errors": ["internal_error"]})),
            )
        }
    })?;

    if let Err(err) = run_carryover_after_create(
        &state,
        user_id,
        plan_id,
        target_plan.farm_id,
        body.source_plan_id,
    ) {
        if err.downcast_ref::<RecordNotFoundError>().is_some() {
            return Err((
                axum::http::StatusCode::NOT_FOUND,
                Json(json!({"errors": ["not_found"]})),
            ));
        }
        let message = err
            .downcast_ref::<agrr_domain::shared::exceptions::RecordInvalidError>()
            .and_then(|invalid| invalid.detail_message())
            .unwrap_or("carryover failed")
            .to_string();
        return Err((
            axum::http::StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": [message]})),
        ));
    }

    let variance_gateway = PlanVarianceLearningSqliteGateway::new(pool);
    let snapshot = variance_gateway
        .find_by_plan_id(plan_id)
        .map_err(|err| {
            tracing::error!("variance_learning import read-back failed: {err}");
            (
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"errors": ["internal_error"]})),
            )
        })?
        .ok_or_else(|| {
            (
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"errors": ["internal_error"]})),
            )
        })?;

    let summary_body = summary_to_json_body(snapshot.summary);
    Ok(Json(json!({
        "plan_id": snapshot.plan_id,
        "source_plan_id": snapshot.source_plan_id,
        "summary": summary_body,
    })))
}

pub fn run_carryover_after_create(
    state: &AppState,
    user_id: i64,
    new_plan_id: i64,
    target_farm_id: i64,
    source_plan_id: i64,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let snapshot_gateway = CultivationPlanPrivateSnapshotReadSqliteGateway::new(pool.clone());
    let variance_gateway = PlanVarianceLearningSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool.clone());
    let scope_gateway = UserOrganizationScopeSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let logger = NoopLogger;

    let interactor = PlanVarianceCarryoverInteractor::new(
        &plan_gateway,
        &snapshot_gateway,
        &variance_gateway,
        &user_lookup,
        &scope_gateway,
        &translator,
        &logger,
    );
    interactor.call(PlanVarianceCarryoverInput {
        new_plan_id,
        source_plan_id,
        target_farm_id,
        user_id,
    })
}
