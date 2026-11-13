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
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"errors": ["internal"]}))))?;
    match port.crop {
        Some(crop) => Ok(crop),
        None => {
            let (status, body) = masters_crop_context_not_found();
            Err((status, Json(body)))
        }
    }
}

pub(crate) fn internal_error() -> (StatusCode, Json<Value>) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(json!({"errors": ["internal"]})),
    )
}

fn masters_crop_context_not_found() -> (StatusCode, Value) {
    (
        StatusCode::NOT_FOUND,
        json!({"errors": ["not found"]}),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn internal_error_returns_500_with_errors_array() {
        let (status, body) = internal_error();
        assert_eq!(status, StatusCode::INTERNAL_SERVER_ERROR);
        assert_eq!(body.0["errors"][0], "internal");
    }

    #[test]
    fn masters_crop_context_not_found_maps_to_404() {
        let (status, body) = masters_crop_context_not_found();
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert_eq!(body["errors"][0], "not found");
    }
}