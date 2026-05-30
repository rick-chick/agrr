//! `GET /api/v1/plans/field_cultivations/{id}` — private plan field cultivation show (P6).

use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::{FieldCultivationClimateSourceSqliteGateway, UserLookupSqliteGateway};
use agrr_domain::field_cultivation::dtos::FieldCultivationApiSummary;
use agrr_domain::field_cultivation::interactors::FieldCultivationShowInteractor;
use agrr_domain::field_cultivation::ports::FieldCultivationApiShowOutputPort;
use agrr_domain::shared::dtos::Error;
use agrr_domain::shared::exceptions::RecordNotFoundError;
use agrr_domain::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use agrr_domain::field_cultivation::dtos::FieldCultivationApiUpdateInput;
use agrr_domain::field_cultivation::interactors::FieldCultivationUpdateInteractor;
use agrr_domain::field_cultivation::ports::{
    FieldCultivationApiUpdateOutputPort, FieldCultivationUpdateFailure,
};
use axum::{
    extract::{Path, State},
    routing::get,
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde::Serialize;
use time::Date;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/plans/field_cultivations/{id}",
            get(show_field_cultivation).patch(update_field_cultivation),
        )
}

pub fn public_routes() -> Router<AppState> {
    Router::new().route(
        "/api/v1/public_plans/field_cultivations/{id}",
        get(show_public_field_cultivation).patch(update_public_field_cultivation),
    )
}

#[derive(Serialize)]
struct FieldCultivationShowItem {
    id: i64,
    field_name: String,
    crop_name: String,
    area: f64,
    start_date: String,
    completion_date: String,
    cultivation_days: i32,
    estimated_cost: f64,
    gdd: Option<f64>,
    status: String,
}

struct ShowPresenter {
    body: Option<ShowOutcome>,
}

enum ShowOutcome {
    Success(FieldCultivationShowItem),
    NotFound,
}

impl FieldCultivationApiShowOutputPort for ShowPresenter {
    fn on_success(&mut self, dto: FieldCultivationApiSummary) {
        self.body = Some(ShowOutcome::Success(FieldCultivationShowItem {
            id: dto.id,
            field_name: dto.field_name,
            crop_name: dto.crop_name,
            area: dto.area,
            start_date: format_date(dto.start_date),
            completion_date: format_date(dto.completion_date),
            cultivation_days: dto.cultivation_days,
            estimated_cost: dto.estimated_cost,
            gdd: dto.gdd,
            status: dto.status,
        }));
    }

    fn on_failure(&mut self, _error: Error) {
        self.body = Some(ShowOutcome::NotFound);
    }
}

fn format_date(date: Date) -> String {
    format!("{date}")
}

async fn show_field_cultivation(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
) -> Result<Json<FieldCultivationShowItem>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(serde_json::json!({"error": "unauthorized"})),
        )
    })?;

    let pool = state.sqlite.clone();
    let gateway =
        FieldCultivationClimateSourceSqliteGateway::new(pool.database_path());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut presenter = ShowPresenter { body: None };

    let mut interactor =
        FieldCultivationShowInteractor::with_user(&mut presenter, &gateway, user_id, &user_lookup);
    if let Err(err) = interactor.call(id) {
        if err.downcast_ref::<RecordNotFoundError>().is_some()
            || err.downcast_ref::<PolicyPermissionDenied>().is_some()
        {
            return Err((
                axum::http::StatusCode::NOT_FOUND,
                Json(serde_json::json!({"error": "not found"})),
            ));
        }
        return Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": "internal"})),
        ));
    }

    match presenter.body {
        Some(ShowOutcome::Success(item)) => Ok(Json(item)),
        Some(ShowOutcome::NotFound) => Err((
            axum::http::StatusCode::NOT_FOUND,
            Json(serde_json::json!({"error": "not found"})),
        )),
        None => Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": "no response"})),
        )),
    }
}

#[derive(serde::Deserialize)]
struct UpdateFieldCultivationBody {
    field_cultivation: UpdateScheduleParams,
}

#[derive(serde::Deserialize)]
struct UpdateScheduleParams {
    start_date: String,
    completion_date: String,
}

struct UpdatePresenter {
    body: Option<UpdateOutcome>,
}

enum UpdateOutcome {
    Success(serde_json::Value),
    NotFound(String),
    Invalid(Vec<String>),
}

impl FieldCultivationApiUpdateOutputPort for UpdatePresenter {
    fn on_success(&mut self, dto: agrr_domain::field_cultivation::dtos::FieldCultivationApiUpdateOutput) {
        self.body = Some(UpdateOutcome::Success(serde_json::json!({
            "success": true,
            "field_cultivation": {
                "id": dto.field_cultivation_id,
                "start_date": dto.start_date,
                "completion_date": dto.completion_date
            }
        })));
    }

    fn on_failure(&mut self, failure: FieldCultivationUpdateFailure) {
        self.body = match failure {
            FieldCultivationUpdateFailure::Message(err) => Some(UpdateOutcome::NotFound(err.message)),
            FieldCultivationUpdateFailure::RecordInvalid(invalid) => {
                Some(UpdateOutcome::Invalid(invalid.flatten_error_messages()))
            }
        };
    }
}

fn map_update_outcome(
    presenter: UpdatePresenter,
) -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    match presenter.body {
        Some(UpdateOutcome::Success(json)) => Ok(Json(json)),
        Some(UpdateOutcome::NotFound(msg)) => Err((
            axum::http::StatusCode::NOT_FOUND,
            Json(serde_json::json!({"error": msg})),
        )),
        Some(UpdateOutcome::Invalid(errors)) => Err((
            axum::http::StatusCode::UNPROCESSABLE_ENTITY,
            Json(serde_json::json!({"success": false, "errors": errors})),
        )),
        None => Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": "no response"})),
        )),
    }
}

async fn update_field_cultivation(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
    Json(body): Json<UpdateFieldCultivationBody>,
) -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(serde_json::json!({"error": "unauthorized"})),
        )
    })?;

    let pool = state.sqlite.clone();
    let gateway =
        FieldCultivationClimateSourceSqliteGateway::new(pool.database_path());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let translator = crate::adapters::PassthroughTranslator;
    let mut presenter = UpdatePresenter { body: None };

    let mut interactor = FieldCultivationUpdateInteractor::with_user(
        &mut presenter,
        &gateway,
        user_id,
        &user_lookup,
        Some(&translator),
    );
    let input = FieldCultivationApiUpdateInput {
        field_cultivation_id: id,
        start_date: body.field_cultivation.start_date,
        completion_date: body.field_cultivation.completion_date,
        public_plan: false,
    };
    interactor.call(input).map_err(|_| {
        (
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": "internal"})),
        )
    })?;

    map_update_outcome(presenter)
}

async fn show_public_field_cultivation(
    State(state): State<AppState>,
    Path(id): Path<i64>,
) -> Result<Json<FieldCultivationShowItem>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    let pool = state.sqlite.clone();
    let gateway =
        FieldCultivationClimateSourceSqliteGateway::new(pool.database_path());
    let mut presenter = ShowPresenter { body: None };
    let mut interactor =
        FieldCultivationShowInteractor::<_, _, UserLookupSqliteGateway>::new(
            &mut presenter,
            &gateway,
        );
    if let Err(err) = interactor.call(id) {
        if err.downcast_ref::<RecordNotFoundError>().is_some()
            || err.downcast_ref::<PolicyPermissionDenied>().is_some()
        {
            return Err((
                axum::http::StatusCode::NOT_FOUND,
                Json(serde_json::json!({"error": "not found"})),
            ));
        }
        return Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": "internal"})),
        ));
    }

    match presenter.body {
        Some(ShowOutcome::Success(item)) => Ok(Json(item)),
        Some(ShowOutcome::NotFound) => Err((
            axum::http::StatusCode::NOT_FOUND,
            Json(serde_json::json!({"error": "not found"})),
        )),
        None => Err((
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": "no response"})),
        )),
    }
}

async fn update_public_field_cultivation(
    State(state): State<AppState>,
    Path(id): Path<i64>,
    Json(body): Json<UpdateFieldCultivationBody>,
) -> Result<Json<serde_json::Value>, (axum::http::StatusCode, Json<serde_json::Value>)> {
    let pool = state.sqlite.clone();
    let gateway =
        FieldCultivationClimateSourceSqliteGateway::new(pool.database_path());
    let mut presenter = UpdatePresenter { body: None };
    let mut interactor = FieldCultivationUpdateInteractor::<
        _,
        _,
        UserLookupSqliteGateway,
        crate::adapters::PassthroughTranslator,
    >::new(&mut presenter, &gateway);
    let input = FieldCultivationApiUpdateInput {
        field_cultivation_id: id,
        start_date: body.field_cultivation.start_date,
        completion_date: body.field_cultivation.completion_date,
        public_plan: true,
    };
    interactor.call(input).map_err(|_| {
        (
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": "internal"})),
        )
    })?;

    map_update_outcome(presenter)
}
