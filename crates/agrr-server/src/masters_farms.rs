//! Masters farms API — `/api/v1/masters/farms`

use crate::adapters::PassthroughTranslator;
use crate::masters_json::{farm_destroy_undo_json, farm_field_to_json, farm_to_json};
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::{FarmSqliteGateway, UserLookupSqliteGateway};
use agrr_domain::shared::gateways::UserLookupGateway;
use agrr_domain::farm::dtos::{FarmCreateInput, FarmListInput, FarmUpdateInput};
use agrr_domain::farm::entities::FarmEntity;
use agrr_domain::farm::interactors::{
    FarmCreateInteractor, FarmDestroyInteractor, FarmDetailInteractor, FarmListInteractor,
    FarmUpdateInteractor,
};
use agrr_domain::farm::ports::{
    CreateFailure, DestroyFailure, DetailFailure, FarmCreateOutputPort, FarmDestroyOutputPort,
    FarmDetailOutputPort, FarmListOutputPort, FarmListSuccess, FarmUpdateOutputPort, ListFailure,
    UpdateFailure,
};
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
        .route("/api/v1/masters/farms", get(list_farms).post(create_farm))
        .route(
            "/api/v1/masters/farms/{id}",
            get(show_farm)
                .patch(update_farm)
                .put(update_farm)
                .delete(destroy_farm),
        )
}

#[derive(Deserialize)]
struct FarmBody {
    farm: FarmAttrs,
}

#[derive(Deserialize)]
struct FarmAttrs {
    name: Option<String>,
    region: Option<String>,
    latitude: Option<f64>,
    longitude: Option<f64>,
}

async fn list_farms(
    State(state): State<AppState>,
    jar: CookieJar,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = FarmSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let user = user_lookup.find(user_id);
    let mut presenter = ListPresenter { body: None };
    let mut interactor =
        FarmListInteractor::new(&mut presenter, user_id, &gateway);
    interactor
        .call(Some(FarmListInput::new(user.admin)))
        .map_err(internal)?;

    match presenter.body {
        Some(Ok(farms)) => Ok(Json(json!(farms.iter().map(farm_to_json).collect::<Vec<_>>()))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn show_farm(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = FarmSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = DetailPresenter { body: None };
    let mut interactor =
        FarmDetailInteractor::new(&mut presenter, user_id, &gateway, &user_lookup);
    interactor.call(id).map_err(internal)?;

    match presenter.body {
        Some(Ok(detail)) => {
            let mut farm_json = farm_to_json(&detail.farm);
            if let Some(obj) = farm_json.as_object_mut() {
                obj.insert(
                    "fields".into(),
                    json!(detail.fields.iter().map(farm_field_to_json).collect::<Vec<_>>()),
                );
            }
            Ok(Json(farm_json))
        }
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn create_farm(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(payload): Json<FarmBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let attrs = &payload.farm;
    if attrs.name.as_deref().unwrap_or("").is_empty()
        || attrs.region.as_deref().unwrap_or("").is_empty()
        || attrs.latitude.is_none()
        || attrs.longitude.is_none()
    {
        return Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": ["name, region, latitude, longitude are required"]})),
        ));
    }
    let user_id = auth_user(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = FarmSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut presenter = CreatePresenter { body: None };
    let mut interactor = FarmCreateInteractor::new(
        &mut presenter,
        user_id,
        &gateway,
        &translator,
        &user_lookup,
    );
    let input = FarmCreateInput::new(
        attrs.name.clone().unwrap(),
        attrs.region.clone(),
        attrs.latitude,
        attrs.longitude,
    );
    interactor.call(input).map_err(internal)?;

    match presenter.body {
        Some(Ok(entity)) => Ok((StatusCode::CREATED, Json(farm_to_json(&entity)))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn update_farm(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
    Json(payload): Json<FarmBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = FarmSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut presenter = UpdatePresenter { body: None };
    let mut interactor = FarmUpdateInteractor::new(
        &mut presenter,
        user_id,
        &gateway,
        &translator,
        &user_lookup,
    );
    let input = FarmUpdateInput {
        farm_id: id,
        name: payload.farm.name.clone(),
        region: payload.farm.region.clone(),
        latitude: payload.farm.latitude,
        longitude: payload.farm.longitude,
    };
    interactor.call(input).map_err(internal)?;

    match presenter.body {
        Some(Ok(entity)) => Ok(Json(farm_to_json(&entity))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

async fn destroy_farm(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(&state, &jar)?;
    let pool = state.sqlite.clone();
    let gateway = FarmSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = PassthroughTranslator;
    let mut presenter = DestroyPresenter { body: None };
    let mut interactor = FarmDestroyInteractor::new(
        &mut presenter,
        user_id,
        &gateway,
        &translator,
        &user_lookup,
    );
    interactor.call(id).map_err(internal)?;

    match presenter.body {
        Some(Ok(output)) => Ok(Json(farm_destroy_undo_json(
            &output.undo,
            &output.farm_name,
            "flash.farms.deleted",
        ))),
        Some(Err((status, body))) => Err((status, Json(body))),
        None => Err(internal_error()),
    }
}

struct ListPresenter {
    body: Option<Result<Vec<FarmEntity>, (StatusCode, Value)>>,
}

impl FarmListOutputPort for ListPresenter {
    fn on_success(&mut self, result: FarmListSuccess) {
        self.body = Some(Ok(result.farms));
    }

    fn on_failure(&mut self, error: ListFailure) {
        self.body = Some(Err(list_failure(error)));
    }
}

struct DetailPresenter {
    body: Option<Result<agrr_domain::farm::dtos::FarmDetailOutput, (StatusCode, Value)>>,
}

impl FarmDetailOutputPort for DetailPresenter {
    fn on_success(&mut self, output: agrr_domain::farm::dtos::FarmDetailOutput) {
        self.body = Some(Ok(output));
    }

    fn on_failure(&mut self, error: DetailFailure) {
        self.body = Some(Err(detail_failure(error)));
    }
}

struct CreatePresenter {
    body: Option<Result<FarmEntity, (StatusCode, Value)>>,
}

impl FarmCreateOutputPort for CreatePresenter {
    fn on_success(&mut self, entity: FarmEntity) {
        self.body = Some(Ok(entity));
    }

    fn on_failure(&mut self, error: CreateFailure) {
        self.body = Some(Err(create_failure(error)));
    }
}

struct UpdatePresenter {
    body: Option<Result<FarmEntity, (StatusCode, Value)>>,
}

impl FarmUpdateOutputPort for UpdatePresenter {
    fn on_success(&mut self, entity: FarmEntity) {
        self.body = Some(Ok(entity));
    }

    fn on_failure(&mut self, error: UpdateFailure) {
        self.body = Some(Err(update_failure(error)));
    }
}

struct DestroyPresenter {
    body: Option<Result<agrr_domain::farm::dtos::FarmDestroyOutput, (StatusCode, Value)>>,
}

impl FarmDestroyOutputPort for DestroyPresenter {
    fn on_success(&mut self, output: agrr_domain::farm::dtos::FarmDestroyOutput) {
        self.body = Some(Ok(output));
    }

    fn on_failure(&mut self, error: DestroyFailure) {
        self.body = Some(Err(destroy_failure(error)));
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

fn list_failure(error: ListFailure) -> (StatusCode, Value) {
    match error {
        ListFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "farms.flash.no_permission"}),
        ),
        ListFailure::Error(e) => (StatusCode::UNPROCESSABLE_ENTITY, json!({"error": e.message})),
    }
}

fn detail_failure(error: DetailFailure) -> (StatusCode, Value) {
    match error {
        DetailFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "farms.flash.no_permission"}),
        ),
        DetailFailure::Error(e) => (
            StatusCode::NOT_FOUND,
            json!({"error": e.message}),
        ),
    }
}

fn create_failure(error: CreateFailure) -> (StatusCode, Value) {
    let msg = match error {
        CreateFailure::LimitExceeded(e) => e.message,
        CreateFailure::Error(e) => e.message,
    };
    (StatusCode::UNPROCESSABLE_ENTITY, json!({"errors": [msg]}))
}

fn update_failure(error: UpdateFailure) -> (StatusCode, Value) {
    match error {
        UpdateFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "farms.flash.no_permission"}),
        ),
        UpdateFailure::Error(e) => (StatusCode::UNPROCESSABLE_ENTITY, json!({"error": e.message})),
    }
}

fn destroy_failure(error: DestroyFailure) -> (StatusCode, Value) {
    match error {
        DestroyFailure::Policy(PolicyPermissionDenied) => (
            StatusCode::FORBIDDEN,
            json!({"error": "farms.flash.no_permission"}),
        ),
        DestroyFailure::Error(e) => (StatusCode::UNPROCESSABLE_ENTITY, json!({"error": e.message})),
    }
}
