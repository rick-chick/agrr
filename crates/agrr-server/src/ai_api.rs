//! AI query endpoints (`/api/v1/crops|fertilizes|pests/*`).

use crate::adapters::{NoopLogger, PassthroughTranslator};
use crate::session_auth::{user_id_from_session, user_id_from_session_or_anonymous};
use crate::state::AppState;
use agrr_adapters_agrr::{
    CropAiQueryDaemonGateway, FertilizeAiQueryDaemonGateway, PestAiQueryDaemonGateway,
};
use agrr_adapters_sqlite::{
    CropAiUpsertSqlitePersistence, CropSqliteGateway, FertilizeSqliteGateway, PestSqliteGateway,
    UserLookupSqliteGateway,
};
use agrr_domain::crop::dtos::{CropAiCreateFailure, CropAiCreateOutput, HttpStatus as CropHttpStatus};
use agrr_domain::crop::interactors::crop_ai_create_interactor::CropAiCreateInteractor;
use agrr_domain::crop::ports::CropAiCreateOutputPort;
use agrr_domain::fertilize::dtos::{
    FertilizeAiCreateFailure, FertilizeAiCreateOutput, HttpStatus as FertilizeHttpStatus,
};
use crate::fertilize_ai_adapters::{FertilizeCreateForAiAdapter, FertilizeUpdateForAiAdapter};
use crate::pest_ai_adapters::{
    AssociateAffectedCropsAdapter, PestCreateForAiAdapter, PestUpdateForAiAdapter,
};
use agrr_adapters_sqlite::{CropPestSqliteGateway, PestCropSqliteGateway};
use agrr_domain::fertilize::interactors::{FertilizeAiCreateInteractor, FertilizeAiUpdateInteractor};
use agrr_domain::fertilize::ports::FertilizeAiCreateOutputPort;
use agrr_domain::pest::interactors::PestAiCreateInteractor;
use agrr_domain::pest::dtos::{
    HttpStatus as PestHttpStatus, PestAiCreateFailure, PestAiCreateOutput,
};
use agrr_domain::pest::interactors::PestAiUpdateInteractor;
use agrr_domain::pest::ports::PestAiCreateOutputPort;
use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::post,
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use serde::Deserialize;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/v1/crops/ai_create", post(crop_ai_create))
        .route("/api/v1/fertilizes/ai_create", post(fertilize_ai_create))
        .route(
            "/api/v1/fertilizes/{id}/ai_update",
            post(fertilize_ai_update),
        )
        .route("/api/v1/pests/ai_create", post(pest_ai_create))
        .route("/api/v1/pests/{id}/ai_update", post(pest_ai_update))
}

fn crop_http_status(status: CropHttpStatus) -> StatusCode {
    match status {
        CropHttpStatus::BadRequest => StatusCode::BAD_REQUEST,
        CropHttpStatus::Unauthorized => StatusCode::UNAUTHORIZED,
        CropHttpStatus::UnprocessableEntity => StatusCode::UNPROCESSABLE_ENTITY,
        CropHttpStatus::ServiceUnavailable => StatusCode::SERVICE_UNAVAILABLE,
    }
}

fn fertilize_http_status(status: FertilizeHttpStatus) -> StatusCode {
    match status {
        FertilizeHttpStatus::Ok => StatusCode::OK,
        FertilizeHttpStatus::Created => StatusCode::CREATED,
        FertilizeHttpStatus::BadRequest => StatusCode::BAD_REQUEST,
        FertilizeHttpStatus::Unauthorized => StatusCode::UNAUTHORIZED,
        FertilizeHttpStatus::NotFound => StatusCode::NOT_FOUND,
        FertilizeHttpStatus::UnprocessableEntity => StatusCode::UNPROCESSABLE_ENTITY,
        FertilizeHttpStatus::ServiceUnavailable => StatusCode::SERVICE_UNAVAILABLE,
    }
}

fn pest_http_status(status: PestHttpStatus) -> StatusCode {
    match status {
        PestHttpStatus::Ok => StatusCode::OK,
        PestHttpStatus::Created => StatusCode::CREATED,
        PestHttpStatus::BadRequest => StatusCode::BAD_REQUEST,
        PestHttpStatus::Unauthorized => StatusCode::UNAUTHORIZED,
        PestHttpStatus::NotFound => StatusCode::NOT_FOUND,
        PestHttpStatus::UnprocessableEntity => StatusCode::UNPROCESSABLE_ENTITY,
        PestHttpStatus::ServiceUnavailable => StatusCode::SERVICE_UNAVAILABLE,
    }
}

fn count_crop_stages(state: &AppState, crop_id: i64) -> i64 {
    state
        .sqlite
        .with_read(|conn| {
            conn.query_row(
                "SELECT COUNT(*) FROM crop_stages WHERE crop_id = ?1",
                [crop_id],
                |row| row.get(0),
            )
        })
        .unwrap_or(0)
}

struct CropAiPresenter {
    state: AppState,
    response: Option<Result<Json<Value>, (StatusCode, Json<Value>)>>,
}

impl CropAiCreateOutputPort for CropAiPresenter {
    fn on_success(&mut self, output: CropAiCreateOutput) {
        let crop = &output.crop;
        let mut body = json!({
            "success": true,
            "crop_id": crop.id,
            "crop_name": crop.name,
            "variety": crop.variety,
            "area_per_unit": crop.area_per_unit,
            "revenue_per_area": crop.revenue_per_area,
            "stages_count": count_crop_stages(&self.state, crop.id),
            "message": "api.crops.ai_create.success"
        });
        if crop.is_reference {
            if let Some(obj) = body.as_object_mut() {
                obj.insert("is_reference".into(), json!(true));
            }
        }
        self.response = Some(Ok(Json(body)));
    }

    fn on_failure(&mut self, failure: CropAiCreateFailure) {
        self.response = Some(Err((
            crop_http_status(failure.http_status),
            Json(json!({ "error": failure.message })),
        )));
    }
}

#[derive(Deserialize)]
struct CropAiBody {
    name: Option<String>,
    variety: Option<String>,
}

async fn crop_ai_create(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(body): Json<CropAiBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session_or_anonymous(&state, &jar).map_err(|status| {
        (status, Json(json!({"error": "unauthorized"})))
    })?;
    let pool = state.sqlite.clone();
    let user_lookup = UserLookupSqliteGateway::new(pool.clone());
    let crop_ai_query = CropAiQueryDaemonGateway::from_env();
    let persistence = CropAiUpsertSqlitePersistence::new(
        CropSqliteGateway::new(pool.clone()),
        user_id,
        UserLookupSqliteGateway::new(pool.clone()),
        PassthroughTranslator,
    );
    let translator = PassthroughTranslator;
    let logger = NoopLogger;
    let mut presenter = CropAiPresenter {
        state: state.clone(),
        response: None,
    };
    let mut interactor = CropAiCreateInteractor::new(
        &mut presenter,
        user_id,
        &user_lookup,
        &translator,
        &logger,
        &crop_ai_query,
        &persistence,
    );
    interactor
        .call(body.name.as_deref().unwrap_or(""), body.variety.as_deref())
        .map_err(|_| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": "internal"})),
            )
        })?;
    presenter
        .response
        .unwrap_or_else(|| {
            Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": "no response"})),
            ))
        })
}

struct FertilizeAiCreatePresenter {
    response: Option<Result<Json<Value>, (StatusCode, Json<Value>)>>,
}

impl FertilizeAiCreateOutputPort for FertilizeAiCreatePresenter {
    fn on_success(&mut self, output: FertilizeAiCreateOutput) {
        self.response = Some(Ok(Json(json!({
            "success": output.success,
            "fertilize_id": output.fertilize_id,
            "fertilize_name": output.fertilize_name,
            "n": output.n,
            "p": output.p,
            "k": output.k,
            "description": output.description,
            "package_size": output.package_size,
            "message": output.message
        }))));
    }

    fn on_failure(&mut self, failure: FertilizeAiCreateFailure) {
        self.response = Some(Err((
            fertilize_http_status(failure.http_status),
            Json(json!({ "error": failure.message })),
        )));
    }
}

#[derive(Deserialize)]
struct FertilizeAiBody {
    name: Option<String>,
}

async fn fertilize_ai_create(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(body): Json<FertilizeAiBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session_or_anonymous(&state, &jar).map_err(|status| {
        (status, Json(json!({"error": "unauthorized"})))
    })?;
    let pool = state.sqlite.clone();
    let gateway = FertilizeSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let ai_query = FertilizeAiQueryDaemonGateway::from_env();
    let translator = PassthroughTranslator;
    let logger = NoopLogger;
    let create_adapter =
        FertilizeCreateForAiAdapter::new(user_id, &gateway, &user_lookup, &translator);
    let update_adapter =
        FertilizeUpdateForAiAdapter::new(user_id, &gateway, &user_lookup, &translator);
    let mut presenter = FertilizeAiCreatePresenter { response: None };
    let mut interactor = FertilizeAiCreateInteractor::new(
        &mut presenter,
        user_id,
        &user_lookup,
        &gateway,
        &ai_query,
        &create_adapter,
        &update_adapter,
        &logger,
        &translator,
    );
    interactor
        .call(body.name.as_deref().unwrap_or(""))
        .map_err(|_| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": "internal"})),
            )
        })?;
    presenter.response.unwrap_or_else(|| {
        Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": "no response"})),
        ))
    })
}

async fn fertilize_ai_update(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
    Json(body): Json<FertilizeAiBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (status, Json(json!({"error": "unauthorized"})))
    })?;
    let pool = state.sqlite.clone();
    let gateway = FertilizeSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let ai_query = FertilizeAiQueryDaemonGateway::from_env();
    let translator = PassthroughTranslator;
    let logger = NoopLogger;
    let update_adapter =
        FertilizeUpdateForAiAdapter::new(user_id, &gateway, &user_lookup, &translator);
    let interactor = FertilizeAiUpdateInteractor::new(
        user_id,
        &user_lookup,
        &gateway,
        &ai_query,
        &update_adapter,
        &logger,
        &translator,
    );
    let envelope = interactor
        .call(id, body.name.as_deref().unwrap_or(""))
        .map_err(|_| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": "internal"})),
            )
        })?;
    Ok((
        fertilize_http_status(envelope.status),
        Json(envelope.body),
    ))
}

struct PestAiCreatePresenter {
    response: Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>,
}

impl PestAiCreateOutputPort for PestAiCreatePresenter {
    fn on_success(&mut self, output: PestAiCreateOutput) {
        let status = pest_http_status(output.http_status);
        self.response = Some(Ok((
            status,
            Json(json!({
                "success": true,
                "pest_id": output.pest_id,
                "pest_name": output.pest_name,
                "name_scientific": output.name_scientific,
                "family": output.family,
                "order": output.order,
                "description": output.description,
                "occurrence_season": output.occurrence_season,
                "message": output.message
            })),
        )));
    }

    fn on_failure(&mut self, failure: PestAiCreateFailure) {
        self.response = Some(Err((
            pest_http_status(failure.http_status),
            Json(json!({ "error": failure.message })),
        )));
    }
}

#[derive(Deserialize)]
struct PestAiBody {
    name: Option<String>,
}

async fn pest_ai_create(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(body): Json<PestAiBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (status, Json(json!({"error": "unauthorized"})))
    })?;
    let pool = state.sqlite.clone();
    let gateway = PestSqliteGateway::new(pool.clone());
    let crop_gateway = PestCropSqliteGateway::new(pool.clone());
    let crop_pest_gateway = CropPestSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let ai_query = PestAiQueryDaemonGateway::from_env();
    let translator = PassthroughTranslator;
    let logger = NoopLogger;
    let create_adapter = PestCreateForAiAdapter::new(
        user_id,
        &gateway,
        &crop_gateway,
        &crop_pest_gateway,
        &user_lookup,
        &translator,
    );
    let update_adapter = PestUpdateForAiAdapter::new(
        user_id,
        &gateway,
        &crop_gateway,
        &crop_pest_gateway,
        &user_lookup,
        &translator,
        &logger,
    );
    let associate = AssociateAffectedCropsAdapter::new(
        user_id,
        &user_lookup,
        &gateway,
        &crop_gateway,
        &crop_pest_gateway,
        &logger,
    );
    let mut presenter = PestAiCreatePresenter { response: None };
    let mut interactor = PestAiCreateInteractor::new(
        &mut presenter,
        user_id,
        &user_lookup,
        &gateway,
        &ai_query,
        &create_adapter,
        &update_adapter,
        &associate,
        &logger,
        &translator,
    );
    interactor
        .call(body.name.as_deref(), &[])
        .map_err(|_| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": "internal"})),
            )
        })?;
    match presenter.response {
        Some(Ok((status, json))) => Ok((status, json)),
        Some(Err(e)) => Err(e),
        None => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": "no response"})),
        )),
    }
}

async fn pest_ai_update(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(id): Path<i64>,
    Json(body): Json<PestAiBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (status, Json(json!({"error": "unauthorized"})))
    })?;
    let pool = state.sqlite.clone();
    let gateway = PestSqliteGateway::new(pool.clone());
    let crop_gateway = PestCropSqliteGateway::new(pool.clone());
    let crop_pest_gateway = CropPestSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let ai_query = PestAiQueryDaemonGateway::from_env();
    let translator = PassthroughTranslator;
    let logger = NoopLogger;
    let update_adapter = PestUpdateForAiAdapter::new(
        user_id,
        &gateway,
        &crop_gateway,
        &crop_pest_gateway,
        &user_lookup,
        &translator,
        &logger,
    );
    let interactor = PestAiUpdateInteractor::new(
        user_id,
        &user_lookup,
        &gateway,
        &ai_query,
        &update_adapter,
        &logger,
        &translator,
    );
    let envelope = interactor
        .call(id, body.name.as_deref().unwrap_or(""))
        .map_err(|_| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": "internal"})),
            )
        })?;
    Ok((pest_http_status(envelope.status), Json(envelope.body)))
}
