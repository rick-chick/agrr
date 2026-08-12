//! `GET /api/v1/plans/:id/variance_learning` — persisted variance learning snapshot.

use crate::adapters::{NoopLogger, PassthroughTranslator};
use crate::plan_vs_actual_json::summary_to_json_body;
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::{
    CultivationPlanPrivateSnapshotReadSqliteGateway, CultivationPlanSqliteGateway,
    PlanVarianceLearningSqliteGateway, UserLookupSqliteGateway, UserOrganizationScopeSqliteGateway,
};
use agrr_domain::cultivation_plan::gateways::PlanVarianceLearningGateway;
use agrr_domain::cultivation_plan::interactors::{
    task_schedule_private_plan_access, PlanVarianceCarryoverInput, PlanVarianceCarryoverInteractor,
};
use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::get,
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new().route(
        "/api/v1/plans/{id}/variance_learning",
        get(show_variance_learning),
    )
}

async fn show_variance_learning(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|status| (status, Json(json!({"error": "unauthorized"}))))?;
    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let variance_gateway = PlanVarianceLearningSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool.clone());
    let scope_gateway = UserOrganizationScopeSqliteGateway::new(pool);
    let org_ids = agrr_domain::shared::org_scope::member_organization_ids(&scope_gateway, user_id)
        .map_err(|_| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": "internal"})),
            )
        })?;

    if !task_schedule_private_plan_access::access_allowed(
        &plan_gateway,
        id,
        user_id,
        &org_ids,
    ) {
        return Err((
            StatusCode::NOT_FOUND,
            Json(json!({"error": "Plan not found"})),
        ));
    }

    match variance_gateway.find_by_plan_id(id).map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": "internal"})),
        )
    })? {
        Some(snapshot) => {
            let summary_body = summary_to_json_body(snapshot.summary);
            Ok(Json(json!({
                "plan_id": snapshot.plan_id,
                "source_plan_id": snapshot.source_plan_id,
                "summary": summary_body,
            })))
        }
        None => Err((
            StatusCode::NOT_FOUND,
            Json(json!({"error": "Variance learning snapshot not found"})),
        )),
    }
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
