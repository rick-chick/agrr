//! `GET /api/v1/plans/:id/variance_learning` — persisted variance learning snapshot.
//! `PATCH /api/v1/plans/:id/variance_learning` — proposal application progress updates.
//! `POST /api/v1/plans/:id/variance_learning/reoptimize` — enqueue optimization job chain.

use crate::adapters::{NoopLogger, PassthroughTranslator};
use crate::optimization_job_chain::enqueue_private_plan_optimization_chain;
use crate::plan_vs_actual_json::summary_to_json_body;
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::{
    CultivationPlanPrivateSnapshotReadSqliteGateway, CultivationPlanSqliteGateway,
    PlanVarianceLearningSqliteGateway, UserLookupSqliteGateway, UserOrganizationScopeSqliteGateway,
};
use agrr_domain::cultivation_plan::dtos::PlanVarianceLearningReoptimizeInput;
use agrr_domain::cultivation_plan::dtos::{
    assemble_plan_variance_learning_snapshot, LearnHandoffStatePatch,
    PlanVarianceLearningSnapshotRead, ReorganizeOrchestrationProgressPatch,
};
use agrr_domain::cultivation_plan::gateways::{
    CultivationPlanGateway, PlanVarianceLearningGateway,
};
use agrr_domain::cultivation_plan::interactors::{
    PlanVarianceCarryoverInput, PlanVarianceCarryoverInteractor,
    PlanVarianceLearningHandoffUpdateInteractor,
    PlanVarianceLearningOrchestrationProgressUpdateInteractor,
    PlanVarianceLearningProposalProgressUpdateInteractor, PlanVarianceLearningReadInteractor,
    PlanVarianceLearningReoptimizeInteractor,
};
use agrr_domain::cultivation_plan::ports::{
    PlanVarianceLearningProposalProgressUpdateOutputPort, PlanVarianceLearningReadOutputPort,
    PlanVarianceLearningReoptimizeEnqueuePort, PlanVarianceLearningReoptimizeOutputPort,
};
use agrr_domain::shared::dtos::Error;
use agrr_domain::shared::exceptions::RecordNotFoundError;
use axum::{
    extract::{Path, State},
    routing::{get, post},
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde_json::{json, Map, Value};
use std::collections::BTreeMap;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/plans/{id}/variance_learning",
            get(show_variance_learning)
                .post(import_variance_learning)
                .patch(patch_variance_learning),
        )
        .route(
            "/api/v1/plans/{id}/variance_learning/reoptimize",
            post(reoptimize_variance_learning),
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

struct VarianceLearningUpdatePresenter {
    body: Option<VarianceLearningUpdateOutcome>,
}

enum VarianceLearningUpdateOutcome {
    Success(PlanVarianceLearningSnapshotRead),
    NotFound,
    Invalid(BTreeMap<String, Vec<String>>, String),
}

impl PlanVarianceLearningProposalProgressUpdateOutputPort for VarianceLearningUpdatePresenter {
    fn on_success(&mut self, dto: PlanVarianceLearningSnapshotRead) {
        self.body = Some(VarianceLearningUpdateOutcome::Success(dto));
    }

    fn on_record_invalid(
        &mut self,
        errors: BTreeMap<String, Vec<String>>,
        fallback_message: &str,
    ) {
        self.body = Some(VarianceLearningUpdateOutcome::Invalid(
            errors,
            fallback_message.to_string(),
        ));
    }

    fn on_not_found(&mut self) {
        self.body = Some(VarianceLearningUpdateOutcome::NotFound);
    }
}

fn snapshot_to_json(snapshot: &PlanVarianceLearningSnapshotRead) -> Value {
    let mut body = Map::new();
    body.insert("plan_id".into(), json!(snapshot.plan_id));
    if let Some(source_plan_id) = snapshot.source_plan_id {
        body.insert("source_plan_id".into(), json!(source_plan_id));
    }
    if let Some(summary) = &snapshot.summary {
        body.insert("summary".into(), summary_to_json_body(summary.clone()));
    }
    body.insert(
        "proposal_application_progress".into(),
        json!(snapshot.proposal_application_progress),
    );
    body.insert(
        "reorganize_orchestration_progress".into(),
        json!({
            "placement": snapshot.reorganize_orchestration_progress.placement,
            "regenerate": snapshot.reorganize_orchestration_progress.regenerate,
            "sync_verify": snapshot.reorganize_orchestration_progress.sync_verify,
            "return_to_learn": snapshot.reorganize_orchestration_progress.return_to_learn,
            "pipeline_active": snapshot.reorganize_orchestration_progress.pipeline_active,
            "current_phase": snapshot.reorganize_orchestration_progress.current_phase,
            "last_error": snapshot.reorganize_orchestration_progress.last_error,
        }),
    );
    let mut handoff = Map::new();
    if let Some(payload) = &snapshot.learn_handoff.post_master_payload {
        handoff.insert("post_master_payload".into(), payload.clone());
    }
    if let Some(context) = &snapshot.learn_handoff.bp_timing_apply_context {
        handoff.insert("bp_timing_apply_context".into(), context.clone());
    }
    if !snapshot.learn_handoff.blueprint_prefill_by_crop_id.is_empty() {
        handoff.insert(
            "blueprint_prefill_by_crop_id".into(),
            Value::Object(
                snapshot
                    .learn_handoff
                    .blueprint_prefill_by_crop_id
                    .iter()
                    .map(|(key, value)| (key.clone(), value.clone()))
                    .collect(),
            ),
        );
    }
    body.insert("learn_handoff".into(), Value::Object(handoff));
    Value::Object(body)
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
                Ok(Json(snapshot_to_json(&snapshot)))
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

#[derive(serde::Deserialize)]
struct PatchVarianceLearningBody {
    proposal_application_progress: Option<BTreeMap<String, String>>,
    reorganize_orchestration_progress: Option<PatchReorganizeOrchestrationProgressBody>,
    learn_handoff: Option<Value>,
}

fn parse_learn_handoff_patch(value: &Value) -> LearnHandoffStatePatch {
    let mut patch = LearnHandoffStatePatch::default();
    let Some(obj) = value.as_object() else {
        return patch;
    };

    if obj.contains_key("post_master_payload") {
        patch.post_master_payload = Some(match obj.get("post_master_payload") {
            Some(Value::Null) | None => None,
            Some(payload) => Some(payload.clone()),
        });
    }

    if obj.contains_key("bp_timing_apply_context") {
        patch.bp_timing_apply_context = Some(match obj.get("bp_timing_apply_context") {
            Some(Value::Null) | None => None,
            Some(context) => Some(context.clone()),
        });
    }

    if let Some(prefill) = obj.get("blueprint_prefill").and_then(|v| v.as_object()) {
        if let Some(crop_id) = prefill.get("crop_id").and_then(|v| v.as_i64()) {
            patch.blueprint_prefill_crop_id = Some(crop_id);
            patch.blueprint_prefill_body = Some(match prefill.get("body") {
                Some(Value::Null) | None => None,
                Some(body) => Some(body.clone()),
            });
        }
    }

    patch
}

fn finalize_patch_response(
    presenter: &VarianceLearningUpdatePresenter,
) -> Result<Json<Value>, (axum::http::StatusCode, Json<Value>)> {
    match &presenter.body {
        Some(VarianceLearningUpdateOutcome::Success(snapshot)) => {
            Ok(Json(snapshot_to_json(snapshot)))
        }
        Some(VarianceLearningUpdateOutcome::NotFound) | None => Err((
            axum::http::StatusCode::NOT_FOUND,
            Json(json!({"errors": ["not_found"]})),
        )),
        Some(VarianceLearningUpdateOutcome::Invalid(errors, fallback)) => {
            let message = errors
                .values()
                .flatten()
                .next()
                .cloned()
                .unwrap_or_else(|| fallback.clone());
            Err((
                axum::http::StatusCode::UNPROCESSABLE_ENTITY,
                Json(json!({"errors": [message]})),
            ))
        }
    }
}

#[derive(serde::Deserialize)]
struct PatchReorganizeOrchestrationProgressBody {
    placement: Option<bool>,
    regenerate: Option<bool>,
    sync_verify: Option<bool>,
    return_to_learn: Option<bool>,
    pipeline_active: Option<bool>,
    current_phase: Option<String>,
    last_error: Option<Option<String>>,
}

async fn patch_variance_learning(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(plan_id): Path<i64>,
    Json(body): Json<PatchVarianceLearningBody>,
) -> Result<Json<Value>, (axum::http::StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(json!({"errors": ["unauthorized"]})),
        )
    })?;

    if body.proposal_application_progress.is_none()
        && body.reorganize_orchestration_progress.is_none()
        && body.learn_handoff.is_none()
    {
        return Err((
            axum::http::StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": ["proposal_application_progress, reorganize_orchestration_progress, or learn_handoff is required"]})),
        ));
    }

    let pool = state.sqlite.clone();
    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let variance_gateway = PlanVarianceLearningSqliteGateway::new(pool.clone());
    let scope_gateway = UserOrganizationScopeSqliteGateway::new(pool);

    let mut presenter = VarianceLearningUpdatePresenter { body: None };

    if let Some(proposal_updates) = body.proposal_application_progress {
        let mut interactor = PlanVarianceLearningProposalProgressUpdateInteractor::new(
            &mut presenter,
            &plan_gateway,
            &variance_gateway,
            &scope_gateway,
        );

        match interactor.call(user_id, plan_id, proposal_updates) {
            Ok(()) => {}
            Err(err) => {
                tracing::error!("variance_learning patch failed: {err}");
                return Err((
                    axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                    Json(json!({"errors": ["internal_error"]})),
                ));
            }
        }
    }

    if let Some(orchestration_body) = body.reorganize_orchestration_progress {
        let orchestration_patch = ReorganizeOrchestrationProgressPatch {
            placement: orchestration_body.placement,
            regenerate: orchestration_body.regenerate,
            sync_verify: orchestration_body.sync_verify,
            return_to_learn: orchestration_body.return_to_learn,
            pipeline_active: orchestration_body.pipeline_active,
            current_phase: orchestration_body.current_phase,
            last_error: orchestration_body.last_error,
        };

        let mut interactor = PlanVarianceLearningOrchestrationProgressUpdateInteractor::new(
            &mut presenter,
            &plan_gateway,
            &variance_gateway,
            &scope_gateway,
        );

        if let Err(err) = interactor.call(user_id, plan_id, orchestration_patch) {
            tracing::error!("variance_learning orchestration patch failed: {err}");
            return Err((
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"errors": ["internal_error"]})),
            ));
        }
    }

    if let Some(handoff_body) = body.learn_handoff {
        let handoff_patch = parse_learn_handoff_patch(&handoff_body);
        let mut interactor = PlanVarianceLearningHandoffUpdateInteractor::new(
            &mut presenter,
            &plan_gateway,
            &variance_gateway,
            &scope_gateway,
        );

        if let Err(err) = interactor.call(user_id, plan_id, handoff_patch) {
            tracing::error!("variance_learning handoff patch failed: {err}");
            return Err((
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"errors": ["internal_error"]})),
            ));
        }
    }

    finalize_patch_response(&presenter)
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

    let variance_gateway = PlanVarianceLearningSqliteGateway::new(pool.clone());
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

    let progress = variance_gateway
        .find_proposal_application_progress_by_plan_id(plan_id)
        .map_err(|err| {
            tracing::error!("variance_learning import progress read failed: {err}");
            (
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"errors": ["internal_error"]})),
            )
        })?;

    let orchestration = variance_gateway
        .find_reorganize_orchestration_progress_by_plan_id(plan_id)
        .map_err(|err| {
            tracing::error!("variance_learning import orchestration read failed: {err}");
            (
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"errors": ["internal_error"]})),
            )
        })?;

    let learn_handoff = variance_gateway
        .find_learn_handoff_by_plan_id(plan_id)
        .map_err(|err| {
            tracing::error!("variance_learning import handoff read failed: {err}");
            (
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"errors": ["internal_error"]})),
            )
        })?;

    let merged = assemble_plan_variance_learning_snapshot(
        snapshot.plan_id,
        Some(snapshot),
        progress,
        orchestration,
        learn_handoff,
    );

    Ok(Json(snapshot_to_json(&merged)))
}

struct VarianceLearningReoptimizeEnqueueAdapter {
    state: AppState,
}

impl PlanVarianceLearningReoptimizeEnqueuePort for VarianceLearningReoptimizeEnqueueAdapter {
    fn enqueue(
        &self,
        plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if enqueue_private_plan_optimization_chain(
            plan_id,
            "PlansOptimizationChannel",
            &self.state,
        ) {
            Ok(())
        } else {
            Err("optimization chain could not start".into())
        }
    }
}

struct VarianceLearningReoptimizePresenter {
    body: Option<VarianceLearningReoptimizeOutcome>,
}

enum VarianceLearningReoptimizeOutcome {
    Success { plan_id: i64 },
    NotFound,
}

impl PlanVarianceLearningReoptimizeOutputPort for VarianceLearningReoptimizePresenter {
    fn on_success(&mut self, plan_id: i64) {
        self.body = Some(VarianceLearningReoptimizeOutcome::Success { plan_id });
    }

    fn on_not_found(&mut self) {
        self.body = Some(VarianceLearningReoptimizeOutcome::NotFound);
    }
}

async fn reoptimize_variance_learning(
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
    let scope_gateway = UserOrganizationScopeSqliteGateway::new(pool);
    let enqueue = VarianceLearningReoptimizeEnqueueAdapter {
        state: state.clone(),
    };
    let mut presenter = VarianceLearningReoptimizePresenter { body: None };

    let mut interactor = PlanVarianceLearningReoptimizeInteractor::new(
        &mut presenter,
        &plan_gateway,
        &enqueue,
        &scope_gateway,
    );

    match interactor.call(PlanVarianceLearningReoptimizeInput { user_id, plan_id }) {
        Ok(()) => match presenter.body {
            Some(VarianceLearningReoptimizeOutcome::Success { plan_id }) => Ok(Json(json!({
                "success": true,
                "plan_id": plan_id,
                "optimization_enqueued": true,
            }))),
            Some(VarianceLearningReoptimizeOutcome::NotFound) | None => Err((
                axum::http::StatusCode::NOT_FOUND,
                Json(json!({"errors": ["not_found"]})),
            )),
        },
        Err(err) => {
            tracing::error!("variance_learning reoptimize failed: {err}");
            Err((
                axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"errors": ["internal_error"]})),
            ))
        }
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
