//! Nested crop stages under `/api/v1/masters/crops/:crop_id/crop_stages`.

use crate::masters_json::crop_stage_to_json;
use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::{CropSqliteGateway, CropStageSqliteGateway, UserLookupSqliteGateway};
use agrr_domain::crop::dtos::{
    CropStageCreateInput, CropStageDeleteInput, CropStageDetailInput, CropStageListInput,
    CropStageUpdateInput,
};
use agrr_domain::crop::interactors::crop_detail_interactor::CropDetailInteractor;
use agrr_domain::crop::interactors::crop_stage_create_interactor::CropStageCreateInteractor;
use agrr_domain::crop::interactors::crop_stage_delete_interactor::CropStageDeleteInteractor;
use agrr_domain::crop::interactors::crop_stage_detail_interactor::CropStageDetailInteractor;
use agrr_domain::crop::interactors::crop_stage_list_interactor::CropStageListInteractor;
use agrr_domain::crop::interactors::crop_stage_update_interactor::CropStageUpdateInteractor;
use agrr_domain::crop::ports::{
    CropDetailOutputPort, CropStageCreateOutputPort, CropStageDeleteOutputPort,
    CropStageDetailOutputPort, CropStageListOutputPort, CropStageUpdateOutputPort, DetailFailure,
};
use agrr_domain::crop::ports::{
    CropStageCreateFailure, CropStageDeleteFailure, CropStageDetailFailure,
    CropStageUpdateFailure,
};
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
        .route(
            "/api/v1/masters/crops/{crop_id}/crop_stages",
            get(index).post(create),
        )
        .route(
            "/api/v1/masters/crops/{crop_id}/crop_stages/{id}",
            get(show).put(update).delete(destroy),
        )
}

pub(crate) async fn ensure_crop_visible(
    state: &AppState,
    user_id: i64,
    crop_id: i64,
) -> Result<(), (StatusCode, Json<Value>)> {
    struct P {
        ok: bool,
    }
    impl CropDetailOutputPort for P {
        fn on_success(&mut self, _: agrr_domain::crop::dtos::CropDetailOutput) {
            self.ok = true;
        }
        fn on_failure(&mut self, _f: DetailFailure) {}
    }
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    let mut p = P { ok: false };
    let mut interactor = CropDetailInteractor::new(&mut p, user_id, &gateway, &user_lookup);
    if interactor.call(crop_id).is_err() || !p.ok {
        return Err((StatusCode::NOT_FOUND, Json(json!({"error": "not found"}))));
    }
    Ok(())
}

async fn index(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(crop_id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool);
    struct P {
        body: Option<Vec<Value>>,
    }
    impl CropStageListOutputPort for P {
        fn on_success(&mut self, output: agrr_domain::crop::dtos::CropStageListOutput) {
            self.body = Some(
                output
                    .stages
                    .iter()
                    .map(crop_stage_to_json)
                    .collect(),
            );
        }
        fn on_failure(&mut self, _: agrr_domain::crop::ports::CropStageListFailure) {}
    }
    let mut p = P { body: None };
    let mut interactor = CropStageListInteractor::new(&mut p, &gateway);
    interactor
        .call(CropStageListInput { crop_id })
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    Ok(Json(json!(p.body.unwrap_or_default())))
}

async fn show(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, id)): Path<(i64, i64)>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
    let pool = state.sqlite.clone();
    let stage_gw = CropStageSqliteGateway::new(pool);
    struct P {
        body: Option<Value>,
        status: StatusCode,
    }
    impl CropStageDetailOutputPort for P {
        fn on_success(&mut self, output: agrr_domain::crop::dtos::CropStageOutput) {
            self.body = Some(crop_stage_to_json(&output.stage));
            self.status = StatusCode::OK;
        }
        fn on_failure(&mut self, _: CropStageDetailFailure) {
            self.status = StatusCode::NOT_FOUND;
        }
    }
    let mut p = P {
        body: None,
        status: StatusCode::NOT_FOUND,
    };
    let mut interactor = CropStageDetailInteractor::new(&mut p, &stage_gw);
    interactor
        .call(CropStageDetailInput { crop_stage_id: id })
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    match p.body {
        Some(v) => Ok(Json(v)),
        None => Err((p.status, Json(json!({"error": "not found"})))),
    }
}

#[derive(Deserialize)]
struct StageBody {
    name: Option<String>,
    order: Option<i64>,
}

async fn create(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(crop_id): Path<i64>,
    Json(body): Json<StageBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
    let payload = json!({
        "name": body.name,
        "order": body.order,
    });
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool);
    struct P {
        resp: Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>,
    }
    impl CropStageCreateOutputPort for P {
        fn on_success(&mut self, output: agrr_domain::crop::dtos::CropStageOutput) {
            self.resp = Some(Ok((
                StatusCode::CREATED,
                Json(crop_stage_to_json(&output.stage)),
            )));
        }
        fn on_failure(&mut self, _: CropStageCreateFailure) {
            self.resp = Some(Err((
                StatusCode::UNPROCESSABLE_ENTITY,
                Json(json!({"errors": ["invalid"]})),
            )));
        }
    }
    let mut p = P { resp: None };
    let mut interactor = CropStageCreateInteractor::new(&mut p, &gateway);
    interactor
        .call(CropStageCreateInput::new(crop_id, payload))
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    p.resp.unwrap_or(Err((
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(json!({"error": "internal"})),
    )))
}

async fn update(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, id)): Path<(i64, i64)>,
    Json(body): Json<StageBody>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
    let payload = json!({
        "name": body.name,
        "order": body.order,
    });
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool);
    struct P {
        body: Option<Value>,
    }
    impl CropStageUpdateOutputPort for P {
        fn on_success(&mut self, output: agrr_domain::crop::dtos::CropStageOutput) {
            self.body = Some(crop_stage_to_json(&output.stage));
        }
        fn on_failure(&mut self, _: CropStageUpdateFailure) {}
    }
    let mut p = P { body: None };
    let mut interactor = CropStageUpdateInteractor::new(&mut p, &gateway);
    interactor
        .call(CropStageUpdateInput {
            crop_stage_id: id,
            payload,
        })
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    match p.body {
        Some(v) => Ok(Json(v)),
        None => Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({"errors": ["invalid"]})),
        )),
    }
}

async fn destroy(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, id)): Path<(i64, i64)>,
) -> Result<StatusCode, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool);
    struct P {
        ok: bool,
    }
    impl CropStageDeleteOutputPort for P {
        fn on_success(&mut self, _: agrr_domain::crop::dtos::CropStageDeleteOutput) {
            self.ok = true;
        }
        fn on_failure(&mut self, _: CropStageDeleteFailure) {}
    }
    let mut p = P { ok: false };
    let mut interactor = CropStageDeleteInteractor::new(&mut p, &gateway);
    interactor
        .call(CropStageDeleteInput { crop_stage_id: id })
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    if p.ok {
        Ok(StatusCode::NO_CONTENT)
    } else {
        Err((StatusCode::NOT_FOUND, Json(json!({"error": "not found"}))))
    }
}
