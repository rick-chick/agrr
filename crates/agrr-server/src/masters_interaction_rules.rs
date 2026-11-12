//! Masters interaction rules API.

use crate::adapters::PassthroughTranslator;
use crate::masters_auth::MastersUserId;
use crate::state::AppState;
use agrr_adapters_sqlite::{InteractionRuleSqliteGateway, UserLookupSqliteGateway};
use agrr_domain::interaction_rule::dtos::{
    InteractionRuleCreateInput, InteractionRuleDestroyOutput, InteractionRuleDetailOutput,
    InteractionRuleUpdateInput,
};
use agrr_domain::interaction_rule::entities::InteractionRuleEntity;
use agrr_domain::interaction_rule::interactors::{
    InteractionRuleCreateInteractor, InteractionRuleDestroyInteractor,
    InteractionRuleDetailInteractor, InteractionRuleListInteractor, InteractionRuleUpdateInteractor,
};
use agrr_domain::interaction_rule::ports::{
    DestroyFailure, DetailFailure, InteractionRuleCreateOutputPort,
    InteractionRuleDestroyOutputPort, InteractionRuleDetailOutputPort,
    InteractionRuleListOutputPort, InteractionRuleUpdateOutputPort, ListFailure, UpdateFailure,
};
use agrr_domain::shared::dtos::Error;
use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    routing::get,
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};
use std::sync::{Arc, Mutex};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/v1/masters/interaction_rules", get(index).post(create))
        .route(
            "/api/v1/masters/interaction_rules/{id}",
            get(show).put(update).patch(update).delete(destroy),
        )
}

fn rule_json(e: &InteractionRuleEntity) -> Value {
    json!({
        "id": e.id,
        "user_id": e.user_id,
        "rule_type": e.rule_type,
        "source_group": e.source_group,
        "target_group": e.target_group,
        "impact_ratio": e.impact_ratio,
        "is_directional": e.is_directional,
        "description": e.description,
        "region": e.region,
        "is_reference": e.is_reference,
        "created_at": e.created_at,
        "updated_at": e.updated_at,
    })
}

fn take_response(
    out: &Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    match out.lock().unwrap().take() {
        Some(Ok(v)) => Ok(v),
        Some(Err(e)) => Err(e),
        None => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"errors": ["internal"]})),
        )),
    }
}

struct ListPort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl InteractionRuleListOutputPort for ListPort {
    fn on_success(&mut self, rows: Vec<InteractionRuleEntity>) {
        let payload: Vec<_> = rows.iter().map(rule_json).collect();
        *self.0.lock().unwrap() = Some(Ok((StatusCode::OK, Json(json!(payload)))));
    }
    fn on_failure(&mut self, failure: ListFailure) {
        let (status, body) = list_failure(failure);
        *self.0.lock().unwrap() = Some(Err((status, Json(body))));
    }
}

fn list_failure(failure: ListFailure) -> (StatusCode, Value) {
    let msg = match failure {
        ListFailure::Error(e) => e.message,
        ListFailure::Policy(_) => "forbidden".into(),
    };
    (StatusCode::FORBIDDEN, json!({"errors": [msg]}))
}

async fn index(
    State(state): State<AppState>,
    auth: MastersUserId,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = InteractionRuleSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut port = ListPort(out.clone());
    let mut interactor =
        InteractionRuleListInteractor::new(&mut port, user_id, &gateway, &user_lookup);
    interactor
        .call()
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"errors": ["internal"]}))))?;
    take_response(&out)
}

struct DetailPort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl InteractionRuleDetailOutputPort for DetailPort {
    fn on_success(&mut self, dto: InteractionRuleDetailOutput) {
        *self.0.lock().unwrap() = Some(Ok((StatusCode::OK, Json(rule_json(&dto.rule)))));
    }
    fn on_failure(&mut self, failure: DetailFailure) {
        let (status, body) = detail_failure(failure);
        *self.0.lock().unwrap() = Some(Err((status, Json(body))));
    }
}

fn detail_failure(failure: DetailFailure) -> (StatusCode, Value) {
    let (status, msg) = match failure {
        DetailFailure::Error(e) => (StatusCode::NOT_FOUND, e.message),
        DetailFailure::Policy(_) => (StatusCode::FORBIDDEN, "forbidden".into()),
    };
    (status, json!({"errors": [msg]}))
}

async fn show(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(id): Path<i64>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = InteractionRuleSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut port = DetailPort(out.clone());
    let mut interactor = InteractionRuleDetailInteractor::new(
        &mut port,
        user_id,
        &gateway,
        &user_lookup,
    );
    interactor
        .call(id)
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"errors": ["internal"]}))))?;
    take_response(&out)
}

#[derive(Deserialize)]
struct RuleRequest {
    interaction_rule: RuleAttrs,
}

#[derive(Deserialize)]
struct RuleAttrs {
    rule_type: Option<String>,
    source_group: Option<String>,
    target_group: Option<String>,
    impact_ratio: Option<f64>,
    is_directional: Option<bool>,
    description: Option<String>,
    region: Option<String>,
    is_reference: Option<bool>,
}

struct CreatePort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl InteractionRuleCreateOutputPort for CreatePort {
    fn on_success(&mut self, entity: InteractionRuleEntity) {
        *self.0.lock().unwrap() = Some(Ok((StatusCode::CREATED, Json(rule_json(&entity)))));
    }
    fn on_failure(&mut self, error: Error) {
        let (status, body) = create_failure(error);
        *self.0.lock().unwrap() = Some(Err((status, Json(body))));
    }
}

fn create_failure(error: Error) -> (StatusCode, Value) {
    (
        StatusCode::UNPROCESSABLE_ENTITY,
        json!({"errors": [error.message]}),
    )
}

async fn create(
    State(state): State<AppState>,
    auth: MastersUserId,
    Json(payload): Json<RuleRequest>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let body = payload.interaction_rule;
    let user_id = auth.0;
    let input = InteractionRuleCreateInput::new(
        body.rule_type.clone().unwrap_or_default(),
        body.source_group.clone().unwrap_or_default(),
        body.target_group.clone().unwrap_or_default(),
        body.impact_ratio.unwrap_or(1.0),
        body.is_directional,
        body.description.clone(),
        body.region.clone(),
        body.is_reference,
    );
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = InteractionRuleSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut port = CreatePort(out.clone());
    let mut interactor = InteractionRuleCreateInteractor::new(
        &mut port,
        user_id,
        &gateway,
        &translator,
        &user_lookup,
    );
    interactor
        .call(input)
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"errors": ["internal"]}))))?;
    take_response(&out)
}

struct UpdatePort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl InteractionRuleUpdateOutputPort for UpdatePort {
    fn on_success(&mut self, entity: InteractionRuleEntity) {
        *self.0.lock().unwrap() = Some(Ok((StatusCode::OK, Json(rule_json(&entity)))));
    }
    fn on_failure(&mut self, failure: UpdateFailure) {
        let (status, body) = update_failure(failure);
        *self.0.lock().unwrap() = Some(Err((status, Json(body))));
    }
}

fn update_failure(failure: UpdateFailure) -> (StatusCode, Value) {
    let msg = match failure {
        UpdateFailure::Error(e) => e.message,
        UpdateFailure::Policy(_) => "forbidden".into(),
        UpdateFailure::ReferenceFlag(_) => "reference flag change denied".into(),
    };
    (StatusCode::UNPROCESSABLE_ENTITY, json!({"errors": [msg]}))
}

async fn update(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(id): Path<i64>,
    Json(payload): Json<RuleRequest>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let body = payload.interaction_rule;
    let user_id = auth.0;
    let input = InteractionRuleUpdateInput {
        id,
        rule_type: body.rule_type.clone(),
        source_group: body.source_group.clone(),
        target_group: body.target_group.clone(),
        impact_ratio: body.impact_ratio,
        is_directional: body.is_directional,
        description: body.description.clone(),
        region: body.region.clone(),
        is_reference: body.is_reference,
    };
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = InteractionRuleSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut port = UpdatePort(out.clone());
    let mut interactor = InteractionRuleUpdateInteractor::new(
        &mut port,
        user_id,
        &gateway,
        &translator,
        &user_lookup,
    );
    interactor
        .call(input)
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"errors": ["internal"]}))))?;
    take_response(&out)
}

struct DestroyPort(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
impl InteractionRuleDestroyOutputPort for DestroyPort {
    fn on_success(&mut self, output: InteractionRuleDestroyOutput) {
        *self.0.lock().unwrap() = Some(Ok((StatusCode::OK, Json(output.undo))));
    }
    fn on_failure(&mut self, failure: DestroyFailure) {
        let (status, body) = destroy_failure(failure);
        *self.0.lock().unwrap() = Some(Err((status, Json(body))));
    }
}

fn destroy_failure(failure: DestroyFailure) -> (StatusCode, Value) {
    let (status, msg) = match failure {
        DestroyFailure::Error(e) => (StatusCode::UNPROCESSABLE_ENTITY, e.message),
        DestroyFailure::Policy(_) => (StatusCode::FORBIDDEN, "forbidden".into()),
    };
    (status, json!({"errors": [msg]}))
}

async fn destroy(
    State(state): State<AppState>,
    auth: MastersUserId,
    headers: HeaderMap,
    Path(id): Path<i64>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let gateway = InteractionRuleSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = state.locale_translator(&headers);
    let mut port = DestroyPort(out.clone());
    let mut interactor = InteractionRuleDestroyInteractor::new(
        &mut port,
        user_id,
        &gateway,
        &translator,
        &user_lookup,
    );
    interactor
        .call(id)
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"errors": ["internal"]}))))?;
    take_response(&out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::interaction_rule::ports::{
        DestroyFailure, DetailFailure, ListFailure, UpdateFailure,
    };
    use agrr_domain::shared::dtos::{Error, ReferenceFlagChangeDeniedFailure};
    use agrr_domain::shared::policies::policy_permission_denied::PolicyPermissionDenied;

    #[test]
    fn list_failure_maps_policy_and_error_both_to_403() {
        let (status, body) = list_failure(ListFailure::Policy(PolicyPermissionDenied));
        assert_eq!(status, StatusCode::FORBIDDEN);
        assert_eq!(body["errors"][0], "forbidden");

        let (status, body) = list_failure(ListFailure::Error(Error::new("db locked")));
        assert_eq!(status, StatusCode::FORBIDDEN);
        assert_eq!(body["errors"][0], "db locked");
    }

    #[test]
    fn detail_failure_maps_not_found_and_policy() {
        let (status, body) = detail_failure(DetailFailure::Error(Error::new("Rule not found")));
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert_eq!(body["errors"][0], "Rule not found");

        let (status, body) = detail_failure(DetailFailure::Policy(PolicyPermissionDenied));
        assert_eq!(status, StatusCode::FORBIDDEN);
        assert_eq!(body["errors"][0], "forbidden");
    }

    #[test]
    fn create_failure_maps_domain_error_to_422() {
        let (status, body) = create_failure(Error::new("invalid rule"));
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(body["errors"][0], "invalid rule");
    }

    #[test]
    fn update_failure_maps_all_variants_to_422_including_policy() {
        let (status, body) = update_failure(UpdateFailure::Error(Error::new("stale")));
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(body["errors"][0], "stale");

        let (status, body) = update_failure(UpdateFailure::Policy(PolicyPermissionDenied));
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(body["errors"][0], "forbidden");

        let (status, body) = update_failure(UpdateFailure::ReferenceFlag(
            ReferenceFlagChangeDeniedFailure::new("denied", 4),
        ));
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(body["errors"][0], "reference flag change denied");
    }

    #[test]
    fn destroy_failure_maps_error_to_422_and_policy_to_403() {
        let (status, body) = destroy_failure(DestroyFailure::Error(Error::new("in use")));
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(body["errors"][0], "in use");

        let (status, body) = destroy_failure(DestroyFailure::Policy(PolicyPermissionDenied));
        assert_eq!(status, StatusCode::FORBIDDEN);
        assert_eq!(body["errors"][0], "forbidden");
    }
}