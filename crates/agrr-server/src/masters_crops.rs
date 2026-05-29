//! Masters crops API — `/api/v1/masters/crops`

use crate::adapters::PassthroughTranslator;
use crate::masters_json::{crop_destroy_undo_json, crop_to_json};
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::{CropSqliteGateway, UserLookupSqliteGateway};
use agrr_domain::crop::dtos::{CropCreateInput, CropDetailOutput, CropUpdateInput};
use agrr_domain::crop::entities::CropEntity;
use agrr_domain::crop::gateways::CropGateway;
use agrr_domain::crop::interactors::crop_create_interactor::CropCreateInteractor;
use agrr_domain::crop::interactors::crop_destroy_interactor::CropDestroyInteractor;
use agrr_domain::crop::interactors::crop_detail_interactor::CropDetailInteractor;
use agrr_domain::crop::interactors::crop_list_interactor::CropListInteractor;
use agrr_domain::crop::interactors::crop_update_interactor::CropUpdateInteractor;
use agrr_domain::crop::ports::{
    CropCreateOutputPort, CropDestroyOutputPort, CropDetailOutputPort, CropListOutputPort,
    CreateFailure, DestroyFailure, DetailFailure, ListFailure,
};
use agrr_domain::shared::dtos::ReferencableListRow;
use agrr_domain::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::get,
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde::Deserialize;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/v1/masters/crops", get(list_crops).post(create_crop))
        .route(
            "/api/v1/masters/crops/{id}",
            get(show_crop)
                .patch(update_crop)
                .put(update_crop)
                .delete(destroy_crop),
        )
}

#[derive(Deserialize)]
struct CropBody {
    crop: CropAttrs,
}

#[derive(Deserialize)]
struct CropAttrs {
    name: Option<String>,
    variety: Option<String>,
    area_per_unit: Option<f64>,
    revenue_per_area: Option<f64>,
    region: Option<String>,
    groups: Option<Vec<String>>,
    is_reference: Option<bool>,
}

async fn list_crops(
    State(state): State<AppState>,
    jar: CookieJar,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = ListPresenter { body: None };
    let mut interactor =
        CropListInteractor::new(&mut presenter, user_id, &gateway, &user_lookup);
    interactor.call().map_err(internal)?;

    match presenter.body {
        Some(Ok(crops)) => Ok(Json(json!(
            crops.iter().map(|c| crop_to_json(c, &[])).collect::<Vec<_>>()
        ))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn show_crop(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = DetailPresenter { body: None };
    let mut interactor =
        CropDetailInteractor::new(&mut presenter, user_id, &gateway, &user_lookup);
    interactor.call(id).map_err(internal)?;

    let stages = gateway.list_by_crop_id(id).unwrap_or_default();

    match presenter.body {
        Some(Ok(detail)) => Ok(Json(crop_to_json(&detail.crop, &stages))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn create_crop(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(payload): Json<CropBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    if payload.crop.name.as_deref().unwrap_or("").is_empty() {
        return Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": ["name is required"]})),
        ));
    }
    let user_id = auth_user(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut presenter = CreatePresenter { body: None };
    let mut interactor = CropCreateInteractor::new(
        &mut presenter,
        user_id,
        &gateway,
        &translator,
        &user_lookup,
    );
    let mut input = CropCreateInput::new(payload.crop.name.clone().unwrap());
    input.variety = payload.crop.variety.clone();
    input.area_per_unit = payload.crop.area_per_unit;
    input.revenue_per_area = payload.crop.revenue_per_area;
    input.region = payload.crop.region.clone();
    input.groups = payload.crop.groups.clone().unwrap_or_default();
    input.is_reference = payload.crop.is_reference.unwrap_or(false);
    interactor.call(input).map_err(internal)?;

    match presenter.body {
        Some(Ok(entity)) => Ok((StatusCode::CREATED, Json(crop_to_json(&entity, &[])))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn update_crop(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
    Json(payload): Json<CropBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut presenter = UpdatePresenter { body: None };
    let mut interactor = CropUpdateInteractor::new(
        &mut presenter,
        user_id,
        &gateway,
        &translator,
        &user_lookup,
    );
    let mut input = CropUpdateInput::new(id);
    input.name = payload.crop.name.clone();
    input.variety = payload.crop.variety.clone();
    input.area_per_unit = payload.crop.area_per_unit;
    input.revenue_per_area = payload.crop.revenue_per_area;
    input.region = payload.crop.region.clone();
    input.groups = payload.crop.groups.clone();
    input.is_reference = payload.crop.is_reference;
    interactor.call(input).map_err(internal)?;

    match presenter.body {
        Some(Ok(entity)) => Ok(Json(crop_to_json(&entity, &[]))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn destroy_crop(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool.clone());
    let crop_name = gateway
        .find_by_id(id)
        .map(|c| c.name)
        .unwrap_or_else(|_| "crop".into());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut presenter = DestroyPresenter { body: None };
    let mut interactor = CropDestroyInteractor::new(
        &mut presenter,
        user_id,
        &gateway,
        &translator,
        &user_lookup,
    );
    interactor.call(id).map_err(internal)?;

    match presenter.body {
        Some(Ok(output)) => Ok(Json(crop_destroy_undo_json(&output.undo, &crop_name))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

struct ListPresenter {
    body: Option<Result<Vec<CropEntity>, (StatusCode, Value)>>,
}

impl CropListOutputPort for ListPresenter {
    fn on_success(&mut self, rows: Vec<ReferencableListRow<CropEntity>>) {
        self.body = Some(Ok(rows.into_iter().map(|r| r.record).collect()));
    }

    fn on_failure(&mut self, error: ListFailure) {
        self.body = Some(Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"error": error_message(&error)}),
        )));
    }
}

struct DetailPresenter {
    body: Option<Result<CropDetailOutput, (StatusCode, Value)>>,
}

impl CropDetailOutputPort for DetailPresenter {
    fn on_success(&mut self, output: CropDetailOutput) {
        self.body = Some(Ok(output));
    }

    fn on_failure(&mut self, error: DetailFailure) {
        self.body = Some(Err(detail_failure(error)));
    }
}

struct CreatePresenter {
    body: Option<Result<CropEntity, (StatusCode, Value)>>,
}

impl CropCreateOutputPort for CreatePresenter {
    fn on_success(&mut self, entity: CropEntity) {
        self.body = Some(Ok(entity));
    }

    fn on_failure(&mut self, error: CreateFailure) {
        self.body = Some(Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            json!({"errors": [error_message_create(&error)]}),
        )));
    }
}

struct UpdatePresenter {
    body: Option<Result<CropEntity, (StatusCode, Value)>>,
}

impl agrr_domain::crop::ports::CropUpdateOutputPort for UpdatePresenter {
    fn on_success(&mut self, entity: CropEntity) {
        self.body = Some(Ok(entity));
    }

    fn on_failure(&mut self, error: agrr_domain::crop::ports::UpdateFailure) {
        use agrr_domain::crop::ports::UpdateFailure;
        let (status, msg) = match error {
            UpdateFailure::Policy(_) => (
                StatusCode::FORBIDDEN,
                "crops.flash.no_permission".to_string(),
            ),
            UpdateFailure::ReferenceFlagChangeDenied(_) => (
                StatusCode::UNPROCESSABLE_ENTITY,
                "crops.flash.reference_flag_denied".to_string(),
            ),
            UpdateFailure::Error(e) => (StatusCode::UNPROCESSABLE_ENTITY, e.message),
        };
        self.body = Some(Err((status, json!({"error": msg}))));
    }
}

struct DestroyPresenter {
    body: Option<Result<agrr_domain::crop::dtos::CropDestroyOutput, (StatusCode, Value)>>,
}

impl CropDestroyOutputPort for DestroyPresenter {
    fn on_success(&mut self, output: agrr_domain::crop::dtos::CropDestroyOutput) {
        self.body = Some(Ok(output));
    }

    fn on_failure(&mut self, error: DestroyFailure) {
        self.body = Some(Err(destroy_failure(error)));
    }
}

fn error_message(error: &ListFailure) -> String {
    match error {
        ListFailure::Error(e) => e.message.clone(),
    }
}

fn error_message_create(error: &CreateFailure) -> String {
    match error {
        CreateFailure::LimitExceeded(e) => e.message.clone(),
        CreateFailure::Error(e) => e.message.clone(),
    }
}

fn detail_failure(error: DetailFailure) -> (StatusCode, Value) {
    match error {
        DetailFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "crops.flash.no_permission"}),
        ),
        DetailFailure::Error(e) => {
            let status = if e.message == "Crop not found" {
                StatusCode::NOT_FOUND
            } else {
                StatusCode::UNPROCESSABLE_ENTITY
            };
            (status, json!({"error": e.message}))
        }
    }
}

fn destroy_failure(error: DestroyFailure) -> (StatusCode, Value) {
    match error {
        DestroyFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "crops.flash.no_permission"}),
        ),
        DestroyFailure::Error(e) => (StatusCode::UNPROCESSABLE_ENTITY, json!({"error": e.message})),
    }
}

fn auth_user(state: &AppState, jar: &CookieJar) -> Result<i64, (StatusCode, Json<Value>)> {
    user_id_from_session(state, jar).map_err(|status| {
        (status, Json(json!({"error": "unauthorized"})))
    })
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
