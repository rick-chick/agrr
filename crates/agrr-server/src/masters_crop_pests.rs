//! Nested crop pests — `/api/v1/masters/crops/{crop_id}/pests`.

use crate::masters_auth::MastersUserId;
use crate::masters_crop_context::{auth_user, internal_error, load_user_non_reference_crop};
use crate::state::AppState;
use agrr_adapters_sqlite::{
    CropPestSqliteGateway, PestCropSqliteGateway, PestSqliteGateway, UserLookupSqliteGateway,
};
use agrr_domain::pest::dtos::MastersCropPestsCreateInput;
use agrr_domain::pest::entities::PestEntity;
use agrr_domain::pest::interactors::{
    MastersCropPestsCreateInteractor, MastersCropPestsDestroyInteractor,
    MastersCropPestsIndexInteractor,
};
use agrr_domain::pest::ports::{
    MastersCropPestsCreateOutputPort, MastersCropPestsDestroyOutputPort,
    MastersCropPestsIndexOutputPort,
};
use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::get,
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};
use std::sync::{Arc, Mutex};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/masters/crops/{crop_id}/pests",
            get(index).post(create),
        )
        .route(
            "/api/v1/masters/crops/{crop_id}/pests/{id}",
            axum::routing::delete(destroy),
        )
}

fn pest_json(entity: &PestEntity) -> Value {
    json!({
        "id": entity.id,
        "user_id": entity.user_id,
        "name": entity.name,
        "name_scientific": entity.name_scientific,
        "family": entity.family,
        "order": entity.order,
        "description": entity.description,
        "occurrence_season": entity.occurrence_season,
        "region": entity.region,
        "is_reference": entity.is_reference,
        "created_at": entity.created_at,
        "updated_at": entity.updated_at,
    })
}

fn take_response(
    out: &Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    match out.lock().unwrap().take() {
        Some(Ok(v)) => Ok(v),
        Some(Err(e)) => Err(e),
        None => Err(internal_error()),
    }
}

async fn index(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(crop_id): Path<i64>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let user_id = auth_user(auth);
    load_user_non_reference_crop(&state, user_id, crop_id).await?;
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let pest_gateway = PestSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    struct Port(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
    impl MastersCropPestsIndexOutputPort for Port {
        fn on_success(&mut self, pests: Vec<PestEntity>) {
            let payload: Vec<_> = pests.iter().map(pest_json).collect();
            *self.0.lock().unwrap() = Some(Ok((StatusCode::OK, Json(json!(payload)))));
        }
    }
    let mut port = Port(out.clone());
    let mut interactor =
        MastersCropPestsIndexInteractor::new(&mut port, user_id, &user_lookup, &pest_gateway);
    interactor
        .call(crop_id)
        .map_err(|_| internal_error())?;
    let (status, body) = take_response(&out)?;
    if status == StatusCode::OK {
        Ok(body)
    } else {
        Err((status, body))
    }
}

#[derive(Deserialize)]
struct CreateBody {
    pest_id: Option<i64>,
}

async fn create(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path(crop_id): Path<i64>,
    Json(body): Json<CreateBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth_user(auth);
    load_user_non_reference_crop(&state, user_id, crop_id).await?;
    let out = Arc::new(Mutex::new(None));
    let pool = state.sqlite.clone();
    let pest_gateway = PestSqliteGateway::new(pool.clone());
    let crop_gateway = PestCropSqliteGateway::new(pool.clone());
    let crop_pest_gateway = CropPestSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    struct Port(Arc<Mutex<Option<Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)>>>>);
    impl MastersCropPestsCreateOutputPort for Port {
        fn on_success(&mut self, crop_id: i64, pest_id: i64) {
            *self.0.lock().unwrap() = Some(Ok((
                StatusCode::CREATED,
                Json(crop_pests_create_success_body(crop_id, pest_id)),
            )));
        }
        fn on_pest_id_missing(&mut self) {
            let (status, body) = crop_pests_create_pest_id_missing();
            *self.0.lock().unwrap() = Some(Err((status, Json(body))));
        }
        fn on_pest_not_found(&mut self) {
            let (status, body) = crop_pests_create_pest_not_found();
            *self.0.lock().unwrap() = Some(Err((status, Json(body))));
        }
        fn on_forbidden(&mut self) {
            let (status, body) = crop_pests_create_forbidden();
            *self.0.lock().unwrap() = Some(Err((status, Json(body))));
        }
        fn on_already_associated(&mut self) {
            let (status, body) = crop_pests_create_already_associated();
            *self.0.lock().unwrap() = Some(Err((status, Json(body))));
        }
    }
    let mut port = Port(out.clone());
    let mut interactor = MastersCropPestsCreateInteractor::new(
        &mut port,
        user_id,
        &user_lookup,
        &pest_gateway,
        &crop_gateway,
        &crop_pest_gateway,
    );
    interactor
        .call(MastersCropPestsCreateInput::new(crop_id, body.pest_id))
        .map_err(|_| internal_error())?;
    take_response(&out)
}

async fn destroy(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, pest_id)): Path<(i64, i64)>,
) -> Result<StatusCode, (StatusCode, Json<Value>)> {
    let user_id = auth_user(auth);
    load_user_non_reference_crop(&state, user_id, crop_id).await?;
    let pool = state.sqlite.clone();
    let pest_gateway = PestSqliteGateway::new(pool.clone());
    let crop_gateway = PestCropSqliteGateway::new(pool.clone());
    let crop_pest_gateway = CropPestSqliteGateway::new(pool.clone());
    let user_lookup = UserLookupSqliteGateway::new(pool);
    struct Port {
        status: Option<Result<StatusCode, (StatusCode, Json<Value>)>>,
    }
    impl MastersCropPestsDestroyOutputPort for Port {
        fn on_success(&mut self) {
            self.status = Some(Ok(StatusCode::NO_CONTENT));
        }
        fn on_crop_not_found(&mut self) {
            let (status, body) = crop_pests_destroy_crop_not_found();
            self.status = Some(Err((status, Json(body))));
        }
        fn on_pest_not_found(&mut self) {
            let (status, body) = crop_pests_destroy_pest_not_found();
            self.status = Some(Err((status, Json(body))));
        }
        fn on_not_associated(&mut self) {
            let (status, body) = crop_pests_destroy_not_associated();
            self.status = Some(Err((status, Json(body))));
        }
    }
    let mut port = Port { status: None };
    let mut interactor = MastersCropPestsDestroyInteractor::new(
        &mut port,
        user_id,
        &user_lookup,
        &pest_gateway,
        &crop_gateway,
        &crop_pest_gateway,
    );
    interactor
        .call(crop_id, pest_id)
        .map_err(|_| internal_error())?;
    match port.status {
        Some(Ok(s)) => Ok(s),
        Some(Err(e)) => Err(e),
        None => Err(internal_error()),
    }
}

fn crop_pests_create_success_body(crop_id: i64, pest_id: i64) -> Value {
    json!({
        "message": "Pest associated successfully",
        "crop_id": crop_id,
        "pest_id": pest_id,
    })
}

fn crop_pests_create_pest_id_missing() -> (StatusCode, Value) {
    (
        StatusCode::UNPROCESSABLE_ENTITY,
        json!({"errors": ["pest_id is required"]}),
    )
}

fn crop_pests_create_pest_not_found() -> (StatusCode, Value) {
    (
        StatusCode::NOT_FOUND,
        json!({"errors": ["Pest not found"]}),
    )
}

fn crop_pests_create_forbidden() -> (StatusCode, Value) {
    (
        StatusCode::FORBIDDEN,
        json!({"errors": ["Permission denied"]}),
    )
}

fn crop_pests_create_already_associated() -> (StatusCode, Value) {
    (
        StatusCode::UNPROCESSABLE_ENTITY,
        json!({"errors": ["Pest is already associated with this crop"]}),
    )
}

fn crop_pests_destroy_crop_not_found() -> (StatusCode, Value) {
    (
        StatusCode::NOT_FOUND,
        json!({"errors": ["Crop not found"]}),
    )
}

fn crop_pests_destroy_pest_not_found() -> (StatusCode, Value) {
    (
        StatusCode::NOT_FOUND,
        json!({"errors": ["Pest not found"]}),
    )
}

fn crop_pests_destroy_not_associated() -> (StatusCode, Value) {
    (
        StatusCode::NOT_FOUND,
        json!({"errors": ["Pest is not associated with this crop"]}),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn crop_pests_create_pest_id_missing_maps_to_422() {
        let (status, body) = crop_pests_create_pest_id_missing();
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(body["errors"][0], "pest_id is required");
    }

    #[test]
    fn crop_pests_create_pest_not_found_maps_to_404() {
        let (status, body) = crop_pests_create_pest_not_found();
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert_eq!(body["errors"][0], "Pest not found");
    }

    #[test]
    fn crop_pests_create_forbidden_maps_to_403() {
        let (status, body) = crop_pests_create_forbidden();
        assert_eq!(status, StatusCode::FORBIDDEN);
        assert_eq!(body["errors"][0], "Permission denied");
    }

    #[test]
    fn crop_pests_create_already_associated_maps_to_422() {
        let (status, body) = crop_pests_create_already_associated();
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(body["errors"][0], "Pest is already associated with this crop");
    }

    #[test]
    fn crop_pests_destroy_crop_not_found_maps_to_404() {
        let (status, body) = crop_pests_destroy_crop_not_found();
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert_eq!(body["errors"][0], "Crop not found");
    }

    #[test]
    fn crop_pests_destroy_pest_not_found_maps_to_404() {
        let (status, body) = crop_pests_destroy_pest_not_found();
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert_eq!(body["errors"][0], "Pest not found");
    }

    #[test]
    fn crop_pests_destroy_not_associated_maps_to_404() {
        let (status, body) = crop_pests_destroy_not_associated();
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert_eq!(body["errors"][0], "Pest is not associated with this crop");
    }

    #[test]
    fn crop_pests_create_success_body_includes_ids() {
        let body = crop_pests_create_success_body(3, 9);
        assert_eq!(body["crop_id"], 3);
        assert_eq!(body["pest_id"], 9);
        assert_eq!(body["message"], "Pest associated successfully");
    }
}