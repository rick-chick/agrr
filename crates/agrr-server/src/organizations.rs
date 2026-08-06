//! Organization CRUD API — `/api/v1/organizations` (ADR-002 phase 1).

use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::{
    OrganizationMembershipSqliteGateway, OrganizationSqliteGateway, UserLookupSqliteGateway,
};
use agrr_domain::organization::dtos::{
    OrganizationCreateInput, OrganizationDeleteFailure, OrganizationFindFailure,
    OrganizationListFailure, OrganizationUpdateInput,
};
use agrr_domain::organization::entities::OrganizationEntity;
use agrr_domain::organization::interactors::{
    OrganizationCreateInteractor, OrganizationDeleteInteractor, OrganizationFindInteractor,
    OrganizationListInteractor, OrganizationUpdateInteractor,
};
use agrr_domain::organization::ports::{
    CreateFailure, OrganizationCreateOutputPort, OrganizationDeleteOutputPort,
    OrganizationFindOutputPort, OrganizationListOutputPort, OrganizationUpdateOutputPort,
    UpdateFailure,
};
use agrr_domain::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde::Deserialize;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/organizations",
            get(list_organizations).post(create_organization),
        )
        .route(
            "/api/v1/organizations/{id}",
            get(show_organization)
                .patch(update_organization)
                .delete(delete_organization),
        )
}

#[derive(Deserialize)]
struct OrganizationBody {
    organization: OrganizationAttrs,
}

#[derive(Deserialize)]
struct OrganizationAttrs {
    name: Option<String>,
    slug: Option<String>,
}

fn organization_to_json(entity: &OrganizationEntity) -> Value {
    json!({
        "id": entity.id,
        "name": entity.name,
        "slug": entity.slug,
        "is_personal": entity.is_personal,
        "created_at": entity.created_at,
        "updated_at": entity.updated_at,
    })
}

async fn list_organizations(
    State(state): State<AppState>,
    jar: CookieJar,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = session_user_id(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = OrganizationSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = ListPresenter { body: None };
    let mut interactor =
        OrganizationListInteractor::new(&mut presenter, &gateway, &user_lookup, user_id);
    interactor.call().map_err(internal)?;

    match presenter.body {
        Some(Ok(organizations)) => Ok(Json(json!(
            organizations
                .iter()
                .map(organization_to_json)
                .collect::<Vec<_>>()
        ))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn show_organization(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = session_user_id(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = OrganizationSqliteGateway::new(pool.clone());
    let membership_gateway = OrganizationMembershipSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = FindPresenter { body: None };
    let mut interactor = OrganizationFindInteractor::new(
        &mut presenter,
        &gateway,
        &membership_gateway,
        &user_lookup,
        user_id,
        id,
    );
    interactor.call().map_err(internal)?;

    match presenter.body {
        Some(Ok(entity)) => Ok(Json(organization_to_json(&entity))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn create_organization(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(payload): Json<OrganizationBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let name = payload.organization.name.unwrap_or_default();
    let slug = payload.organization.slug.unwrap_or_default();
    let user_id = session_user_id(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = OrganizationSqliteGateway::new(pool.clone());
    let membership_gateway = OrganizationMembershipSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = CreatePresenter { body: None };
    let mut interactor = OrganizationCreateInteractor::new(
        &mut presenter,
        &gateway,
        &membership_gateway,
        &user_lookup,
        user_id,
    );
    let input = OrganizationCreateInput {
        name,
        slug,
    };
    interactor.call(input).map_err(internal)?;

    match presenter.body {
        Some(Ok(entity)) => Ok((StatusCode::CREATED, Json(organization_to_json(&entity)))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn update_organization(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
    Json(payload): Json<OrganizationBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = session_user_id(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = OrganizationSqliteGateway::new(pool.clone());
    let membership_gateway = OrganizationMembershipSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = UpdatePresenter { body: None };
    let mut interactor = OrganizationUpdateInteractor::new(
        &mut presenter,
        &gateway,
        &membership_gateway,
        &user_lookup,
        user_id,
        id,
    );
    let input = OrganizationUpdateInput {
        name: payload.organization.name,
        slug: payload.organization.slug,
    };
    interactor.call(input).map_err(internal)?;

    match presenter.body {
        Some(Ok(entity)) => Ok(Json(organization_to_json(&entity))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn delete_organization(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
) -> Result<impl IntoResponse, (StatusCode, Json<Value>)> {
    let user_id = session_user_id(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = OrganizationSqliteGateway::new(pool.clone());
    let membership_gateway = OrganizationMembershipSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = DeletePresenter { body: None };
    let mut interactor = OrganizationDeleteInteractor::new(
        &mut presenter,
        &gateway,
        &membership_gateway,
        &user_lookup,
        user_id,
        id,
    );
    interactor.call().map_err(internal)?;

    match presenter.body {
        Some(Ok(())) => Ok(StatusCode::NO_CONTENT),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

fn session_user_id(state: &AppState, jar: &CookieJar) -> Result<i64, (StatusCode, Json<Value>)> {
    user_id_from_session(state, jar).map_err(|status| {
        (
            status,
            Json(json!({"error": "unauthorized"})),
        )
    })
}

struct ListPresenter {
    body: Option<Result<Vec<OrganizationEntity>, (StatusCode, Value)>>,
}

impl OrganizationListOutputPort for ListPresenter {
    fn on_success(&mut self, organizations: Vec<OrganizationEntity>) {
        self.body = Some(Ok(organizations));
    }

    fn on_failure(&mut self, failure: OrganizationListFailure) {
        self.body = Some(Err(list_failure(failure)));
    }
}

struct FindPresenter {
    body: Option<Result<OrganizationEntity, (StatusCode, Value)>>,
}

impl OrganizationFindOutputPort for FindPresenter {
    fn on_success(&mut self, organization: OrganizationEntity) {
        self.body = Some(Ok(organization));
    }

    fn on_failure(&mut self, failure: OrganizationFindFailure) {
        self.body = Some(Err(find_failure(failure)));
    }
}

struct CreatePresenter {
    body: Option<Result<OrganizationEntity, (StatusCode, Value)>>,
}

impl OrganizationCreateOutputPort for CreatePresenter {
    fn on_success(&mut self, organization: OrganizationEntity) {
        self.body = Some(Ok(organization));
    }

    fn on_failure(&mut self, failure: CreateFailure) {
        self.body = Some(Err(create_failure(failure)));
    }
}

struct UpdatePresenter {
    body: Option<Result<OrganizationEntity, (StatusCode, Value)>>,
}

impl OrganizationUpdateOutputPort for UpdatePresenter {
    fn on_success(&mut self, organization: OrganizationEntity) {
        self.body = Some(Ok(organization));
    }

    fn on_failure(&mut self, failure: UpdateFailure) {
        self.body = Some(Err(update_failure(failure)));
    }
}

struct DeletePresenter {
    body: Option<Result<(), (StatusCode, Value)>>,
}

impl OrganizationDeleteOutputPort for DeletePresenter {
    fn on_success(&mut self) {
        self.body = Some(Ok(()));
    }

    fn on_failure(&mut self, failure: OrganizationDeleteFailure) {
        self.body = Some(Err(delete_failure(failure)));
    }
}

fn internal(_: Box<dyn std::error::Error + Send + Sync>) -> (StatusCode, Json<Value>) {
    internal_error()
}

fn internal_error() -> (StatusCode, Json<Value>) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(json!({"error": "internal"})),
    )
}

fn list_failure(error: OrganizationListFailure) -> (StatusCode, Value) {
    match error {
        OrganizationListFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "organizations.flash.no_permission"}),
        ),
        OrganizationListFailure::Error(e) => (
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"error": e.message}),
        ),
    }
}

fn find_failure(error: OrganizationFindFailure) -> (StatusCode, Value) {
    match error {
        OrganizationFindFailure::NotFound => (
            StatusCode::NOT_FOUND,
            json!({"error": "organization not found"}),
        ),
        OrganizationFindFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "organizations.flash.no_permission"}),
        ),
        OrganizationFindFailure::Error(e) => (
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"error": e.message}),
        ),
    }
}

fn create_failure(error: CreateFailure) -> (StatusCode, Value) {
    match error {
        CreateFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "organizations.flash.no_permission"}),
        ),
        CreateFailure::Error(e) => (
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"errors": [e.message]}),
        ),
    }
}

fn update_failure(error: UpdateFailure) -> (StatusCode, Value) {
    match error {
        UpdateFailure::NotFound => (
            StatusCode::NOT_FOUND,
            json!({"error": "organization not found"}),
        ),
        UpdateFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "organizations.flash.no_permission"}),
        ),
        UpdateFailure::Error(e) => (
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"error": e.message}),
        ),
    }
}

fn delete_failure(error: OrganizationDeleteFailure) -> (StatusCode, Value) {
    match error {
        OrganizationDeleteFailure::PersonalOrgForbidden => (
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"error": "organizations.personal_delete_forbidden"}),
        ),
        OrganizationDeleteFailure::NotFound => (
            StatusCode::NOT_FOUND,
            json!({"error": "organization not found"}),
        ),
        OrganizationDeleteFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "organizations.flash.no_permission"}),
        ),
        OrganizationDeleteFailure::Error(e) => (
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"error": e.message}),
        ),
    }
}
