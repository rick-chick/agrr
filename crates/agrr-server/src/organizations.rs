//! Organization CRUD API — `/api/v1/organizations` (ADR-002 phase 1).

use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::{
    OrganizationMembershipSqliteGateway, OrganizationSqliteGateway, UserLookupSqliteGateway,
};
use agrr_domain::organization::dtos::{
    OrganizationCreateInput, OrganizationDeleteFailure, OrganizationFindFailure,
    OrganizationListFailure, OrganizationMembershipCreateFailure,
    OrganizationMembershipCreateInput, OrganizationMembershipDeleteFailure,
    OrganizationMembershipListFailure, OrganizationMembershipUpdateFailure,
    OrganizationMembershipUpdateInput, OrganizationRole, OrganizationUpdateInput,
};
use agrr_domain::organization::entities::{OrganizationEntity, OrganizationMembershipEntity};
use agrr_domain::organization::interactors::{
    OrganizationCreateInteractor, OrganizationDeleteInteractor, OrganizationFindInteractor,
    OrganizationListInteractor, OrganizationMembershipCreateInteractor,
    OrganizationMembershipDeleteInteractor, OrganizationMembershipListInteractor,
    OrganizationMembershipUpdateInteractor, OrganizationUpdateInteractor,
};
use agrr_domain::organization::ports::{
    CreateFailure, OrganizationCreateOutputPort, OrganizationDeleteOutputPort,
    OrganizationFindOutputPort, OrganizationListOutputPort,
    OrganizationMembershipCreateOutputPort, OrganizationMembershipDeleteOutputPort,
    OrganizationMembershipListOutputPort, OrganizationMembershipUpdateOutputPort,
    OrganizationUpdateOutputPort, UpdateFailure,
};
use agrr_domain::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, patch},
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
        .route(
            "/api/v1/organizations/{id}/memberships",
            get(list_memberships).post(create_membership),
        )
        .route(
            "/api/v1/organizations/{id}/memberships/{user_id}",
            patch(update_membership).delete(delete_membership),
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

fn membership_to_json(entity: &OrganizationMembershipEntity) -> Value {
    json!({
        "id": entity.id,
        "organization_id": entity.organization_id,
        "user_id": entity.user_id,
        "role": entity.role.as_str(),
        "created_at": entity.created_at,
        "updated_at": entity.updated_at,
    })
}

#[derive(Deserialize)]
struct MembershipBody {
    membership: MembershipAttrs,
}

#[derive(Deserialize)]
struct MembershipAttrs {
    user_id: Option<i64>,
    role: Option<String>,
}

fn parse_role(value: &str) -> Option<OrganizationRole> {
    OrganizationRole::parse(value.trim())
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

async fn list_memberships(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = session_user_id(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = OrganizationSqliteGateway::new(pool.clone());
    let membership_gateway = OrganizationMembershipSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = MembershipListPresenter { body: None };
    let mut interactor = OrganizationMembershipListInteractor::new(
        &mut presenter,
        &gateway,
        &membership_gateway,
        &user_lookup,
        user_id,
        id,
    );
    interactor.call().map_err(internal)?;

    match presenter.body {
        Some(Ok(memberships)) => Ok(Json(json!(
            memberships.iter().map(membership_to_json).collect::<Vec<_>>()
        ))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn create_membership(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
    Json(payload): Json<MembershipBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let target_user_id = payload.membership.user_id.unwrap_or(0);
    let role_str = payload.membership.role.unwrap_or_default();
    if target_user_id <= 0 {
        return Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"error": "user_id is required"})),
        ));
    }
    let role = if role_str.trim().is_empty() {
        OrganizationRole::Member
    } else {
        match parse_role(&role_str) {
            Some(r) => r,
            None => {
                return Err((
                    StatusCode::UNPROCESSABLE_ENTITY,
                    Json(json!({"error": "invalid role"})),
                ));
            }
        }
    };
    let user_id = session_user_id(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = OrganizationSqliteGateway::new(pool.clone());
    let membership_gateway = OrganizationMembershipSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = MembershipCreatePresenter { body: None };
    let mut interactor = OrganizationMembershipCreateInteractor::new(
        &mut presenter,
        &gateway,
        &membership_gateway,
        &user_lookup,
        user_id,
        id,
    );
    let input = OrganizationMembershipCreateInput {
        user_id: target_user_id,
        role,
    };
    interactor.call(input).map_err(internal)?;

    match presenter.body {
        Some(Ok(entity)) => Ok((StatusCode::CREATED, Json(membership_to_json(&entity)))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn update_membership(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((id, target_user_id)): Path<(i64, i64)>,
    Json(payload): Json<MembershipBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let role_str = payload
        .membership
        .role
        .unwrap_or_default();
    let role = match parse_role(&role_str) {
        Some(r) => r,
        None => {
            return Err((
                StatusCode::UNPROCESSABLE_ENTITY,
                Json(json!({"error": "invalid role"})),
            ));
        }
    };
    let user_id = session_user_id(&state, &jar)?;
    let pool = state.sqlite.clone();
    let membership_gateway = OrganizationMembershipSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = MembershipUpdatePresenter { body: None };
    let mut interactor = OrganizationMembershipUpdateInteractor::new(
        &mut presenter,
        &membership_gateway,
        &user_lookup,
        user_id,
        id,
        target_user_id,
    );
    let input = OrganizationMembershipUpdateInput { role };
    interactor.call(input).map_err(internal)?;

    match presenter.body {
        Some(Ok(entity)) => Ok(Json(membership_to_json(&entity))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn delete_membership(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((id, target_user_id)): Path<(i64, i64)>,
) -> Result<impl IntoResponse, (StatusCode, Json<Value>)> {
    let user_id = session_user_id(&state, &jar)?;
    let pool = state.sqlite.clone();
    let membership_gateway = OrganizationMembershipSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = MembershipDeletePresenter { body: None };
    let mut interactor = OrganizationMembershipDeleteInteractor::new(
        &mut presenter,
        &membership_gateway,
        &user_lookup,
        user_id,
        id,
        target_user_id,
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

struct MembershipListPresenter {
    body: Option<Result<Vec<OrganizationMembershipEntity>, (StatusCode, Value)>>,
}

impl OrganizationMembershipListOutputPort for MembershipListPresenter {
    fn on_success(&mut self, memberships: Vec<OrganizationMembershipEntity>) {
        self.body = Some(Ok(memberships));
    }

    fn on_failure(&mut self, failure: OrganizationMembershipListFailure) {
        self.body = Some(Err(membership_list_failure(failure)));
    }
}

struct MembershipCreatePresenter {
    body: Option<Result<OrganizationMembershipEntity, (StatusCode, Value)>>,
}

impl OrganizationMembershipCreateOutputPort for MembershipCreatePresenter {
    fn on_success(&mut self, membership: OrganizationMembershipEntity) {
        self.body = Some(Ok(membership));
    }

    fn on_failure(&mut self, failure: OrganizationMembershipCreateFailure) {
        self.body = Some(Err(membership_create_failure(failure)));
    }
}

struct MembershipUpdatePresenter {
    body: Option<Result<OrganizationMembershipEntity, (StatusCode, Value)>>,
}

impl OrganizationMembershipUpdateOutputPort for MembershipUpdatePresenter {
    fn on_success(&mut self, membership: OrganizationMembershipEntity) {
        self.body = Some(Ok(membership));
    }

    fn on_failure(&mut self, failure: OrganizationMembershipUpdateFailure) {
        self.body = Some(Err(membership_update_failure(failure)));
    }
}

struct MembershipDeletePresenter {
    body: Option<Result<(), (StatusCode, Value)>>,
}

impl OrganizationMembershipDeleteOutputPort for MembershipDeletePresenter {
    fn on_success(&mut self) {
        self.body = Some(Ok(()));
    }

    fn on_failure(&mut self, failure: OrganizationMembershipDeleteFailure) {
        self.body = Some(Err(membership_delete_failure(failure)));
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

fn membership_list_failure(error: OrganizationMembershipListFailure) -> (StatusCode, Value) {
    match error {
        OrganizationMembershipListFailure::NotFound => (
            StatusCode::NOT_FOUND,
            json!({"error": "organization not found"}),
        ),
        OrganizationMembershipListFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "organizations.flash.no_permission"}),
        ),
        OrganizationMembershipListFailure::Error(e) => (
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"error": e.message}),
        ),
    }
}

fn membership_create_failure(error: OrganizationMembershipCreateFailure) -> (StatusCode, Value) {
    match error {
        OrganizationMembershipCreateFailure::AlreadyMember => (
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"error": "organizations.memberships.already_member"}),
        ),
        OrganizationMembershipCreateFailure::NotFound => (
            StatusCode::NOT_FOUND,
            json!({"error": "user or organization not found"}),
        ),
        OrganizationMembershipCreateFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "organizations.flash.no_permission"}),
        ),
        OrganizationMembershipCreateFailure::Error(e) => (
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"error": e.message}),
        ),
    }
}

fn membership_update_failure(error: OrganizationMembershipUpdateFailure) -> (StatusCode, Value) {
    match error {
        OrganizationMembershipUpdateFailure::LastOwnerForbidden => (
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"error": "organizations.memberships.last_owner_forbidden"}),
        ),
        OrganizationMembershipUpdateFailure::NotFound => (
            StatusCode::NOT_FOUND,
            json!({"error": "membership not found"}),
        ),
        OrganizationMembershipUpdateFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "organizations.flash.no_permission"}),
        ),
        OrganizationMembershipUpdateFailure::Error(e) => (
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"error": e.message}),
        ),
    }
}

fn membership_delete_failure(error: OrganizationMembershipDeleteFailure) -> (StatusCode, Value) {
    match error {
        OrganizationMembershipDeleteFailure::LastOwnerForbidden => (
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"error": "organizations.memberships.last_owner_forbidden"}),
        ),
        OrganizationMembershipDeleteFailure::NotFound => (
            StatusCode::NOT_FOUND,
            json!({"error": "membership not found"}),
        ),
        OrganizationMembershipDeleteFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "organizations.flash.no_permission"}),
        ),
        OrganizationMembershipDeleteFailure::Error(e) => (
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"error": e.message}),
        ),
    }
}
