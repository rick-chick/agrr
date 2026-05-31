//! Shared crop context load for masters nested routes.

use crate::masters_auth::MastersUserId;
use crate::state::AppState;
use agrr_adapters_sqlite::{CropSqliteGateway, UserLookupSqliteGateway};
use agrr_domain::crop::entities::CropEntity;
use agrr_domain::crop::interactors::crop_load_user_non_reference_for_masters_interactor::{
    CropLoadUserNonReferenceForMastersInteractor, CropLoadUserNonReferenceForMastersOutputPort,
};
use axum::http::StatusCode;
use axum::Json;
use serde_json::{json, Value};

pub(crate) fn auth_user(auth: MastersUserId) -> i64 {
    auth.0
}

/// Loads a user-owned non-reference crop for masters nested APIs (404 when missing or not allowed).
pub(crate) async fn load_user_non_reference_crop(
    state: &AppState,
    user_id: i64,
    crop_id: i64,
) -> Result<CropEntity, (StatusCode, Json<Value>)> {
    let pool = state.sqlite.clone();
    let gateway = CropSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    struct Port {
        crop: Option<CropEntity>,
    }
    impl CropLoadUserNonReferenceForMastersOutputPort for Port {
        fn on_success(&mut self, crop: CropEntity) {
            self.crop = Some(crop);
        }
        fn on_not_found(&mut self) {}
    }
    let mut port = Port { crop: None };
    let mut interactor =
        CropLoadUserNonReferenceForMastersInteractor::new(&mut port, user_id, &gateway, &user_lookup);
    interactor
        .call(crop_id)
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    match port.crop {
        Some(crop) => Ok(crop),
        None => Err((StatusCode::NOT_FOUND, Json(json!({"error": "not found"})))),
    }
}

pub(crate) fn internal_error() -> (StatusCode, Json<Value>) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(json!({"error": "internal"})),
    )
}
