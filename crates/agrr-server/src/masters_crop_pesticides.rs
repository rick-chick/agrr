//! Nested crop pesticides index — `/api/v1/masters/crops/{crop_id}/pesticides`.

use crate::masters_crop_context::{auth_user, internal_error, load_user_non_reference_crop};
use crate::state::AppState;
use agrr_adapters_sqlite::{
    PesticideCropSqliteGateway, PesticideSqliteGateway, UserLookupSqliteGateway,
};
use agrr_domain::pesticide::entities::PesticideEntity;
use agrr_domain::pesticide::interactors::MastersCropPesticidesIndexInteractor;
use agrr_domain::pesticide::ports::MastersCropPesticidesIndexOutputPort;
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
        "/api/v1/masters/crops/{crop_id}/pesticides",
        get(index),
    )
}

fn pesticide_json(e: &PesticideEntity) -> Value {
    json!({
        "id": e.id,
        "user_id": e.user_id,
        "name": e.name,
        "active_ingredient": e.active_ingredient,
        "description": e.description,
        "crop_id": e.crop_id,
        "pest_id": e.pest_id,
        "region": e.region,
        "is_reference": e.is_reference,
        "created_at": e.created_at,
        "updated_at": e.updated_at,
    })
}

async fn index(
    State(state): State<AppState>,
    jar: CookieJar,
    Path(crop_id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(&state, &jar).await?;
    load_user_non_reference_crop(&state, user_id, crop_id).await?;
    let pool = state.sqlite.clone();
    let pesticide_gateway = PesticideSqliteGateway::new(pool.clone());
    let crop_gateway = PesticideCropSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    struct Port {
        body: Option<Result<Json<Value>, (StatusCode, Json<Value>)>>,
    }
    impl MastersCropPesticidesIndexOutputPort for Port {
        fn on_success(&mut self, pesticides: Vec<PesticideEntity>) {
            let payload: Vec<_> = pesticides.iter().map(pesticide_json).collect();
            self.body = Some(Ok(Json(json!(payload))));
        }
        fn on_not_found(&mut self) {
            self.body = Some(Err((
                StatusCode::NOT_FOUND,
                Json(json!({"error": "Crop not found"})),
            )));
        }
    }
    let mut port = Port { body: None };
    let mut interactor = MastersCropPesticidesIndexInteractor::new(
        &mut port,
        user_id,
        &user_lookup,
        &pesticide_gateway,
        &crop_gateway,
    );
    interactor
        .call(crop_id)
        .map_err(|_| internal_error())?;
    match port.body {
        Some(Ok(json)) => Ok(json),
        Some(Err(e)) => Err(e),
        None => Err(internal_error()),
    }
}
