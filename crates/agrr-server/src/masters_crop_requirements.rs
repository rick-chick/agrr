//! Nested crop stage requirements under masters crops.

use crate::masters_crop_stages::ensure_authorized_crop_stage;
use crate::masters_auth::MastersUserId;
use crate::state::AppState;
use agrr_adapters_sqlite::{
    CropSqliteGateway, NutrientRequirementSqliteGateway, SunshineRequirementSqliteGateway,
    TemperatureRequirementSqliteGateway, ThermalRequirementSqliteGateway,
};
use agrr_domain::crop::dtos::{
    CropStageDetailInput, NutrientRequirementUpdateInput, SunshineRequirementUpdateInput,
    TemperatureRequirementUpdateInput, ThermalRequirementUpdateInput,
};
use agrr_domain::crop::entities::{
    NutrientRequirementEntity, SunshineRequirementEntity, TemperatureRequirementEntity,
    ThermalRequirementEntity,
};
use agrr_domain::crop::interactors::masters_nutrient_requirement_create_interactor::MastersNutrientRequirementCreateInteractor;
use agrr_domain::crop::interactors::masters_nutrient_requirement_destroy_interactor::MastersNutrientRequirementDestroyInteractor;
use agrr_domain::crop::interactors::masters_nutrient_requirement_show_interactor::MastersNutrientRequirementShowInteractor;
use agrr_domain::crop::interactors::masters_nutrient_requirement_update_interactor::MastersNutrientRequirementUpdateInteractor;
use agrr_domain::crop::interactors::masters_sunshine_requirement_create_interactor::MastersSunshineRequirementCreateInteractor;
use agrr_domain::crop::interactors::masters_sunshine_requirement_destroy_interactor::MastersSunshineRequirementDestroyInteractor;
use agrr_domain::crop::interactors::masters_sunshine_requirement_show_interactor::MastersSunshineRequirementShowInteractor;
use agrr_domain::crop::interactors::masters_sunshine_requirement_update_interactor::MastersSunshineRequirementUpdateInteractor;
use agrr_domain::crop::interactors::masters_temperature_requirement_create_interactor::MastersTemperatureRequirementCreateInteractor;
use agrr_domain::crop::interactors::masters_temperature_requirement_destroy_interactor::MastersTemperatureRequirementDestroyInteractor;
use agrr_domain::crop::interactors::masters_temperature_requirement_show_interactor::MastersTemperatureRequirementShowInteractor;
use agrr_domain::crop::interactors::masters_temperature_requirement_update_interactor::MastersTemperatureRequirementUpdateInteractor;
use agrr_domain::crop::interactors::masters_thermal_requirement_create_interactor::MastersThermalRequirementCreateInteractor;
use agrr_domain::crop::interactors::masters_thermal_requirement_destroy_interactor::MastersThermalRequirementDestroyInteractor;
use agrr_domain::crop::interactors::masters_thermal_requirement_show_interactor::MastersThermalRequirementShowInteractor;
use agrr_domain::crop::interactors::masters_thermal_requirement_update_interactor::MastersThermalRequirementUpdateInteractor;
use agrr_domain::crop::ports::{
    MastersNutrientRequirementOutputPort, MastersSunshineRequirementOutputPort,
    MastersTemperatureRequirementOutputPort, MastersThermalRequirementOutputPort,
};
use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::get,
    Json, Router,
};
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new()
        .nest(
            "/api/v1/masters/crops/{crop_id}/crop_stages/{stage_id}",
            Router::new()
                .route(
                    "/temperature_requirement",
                    get(temperature_show)
                        .post(temperature_create)
                        .put(temperature_update)
                        .patch(temperature_update)
                        .delete(temperature_destroy),
                )
                .route(
                    "/thermal_requirement",
                    get(thermal_show)
                        .post(thermal_create)
                        .put(thermal_update)
                        .patch(thermal_update)
                        .delete(thermal_destroy),
                )
                .route(
                    "/sunshine_requirement",
                    get(sunshine_show)
                        .post(sunshine_create)
                        .put(sunshine_update)
                        .patch(sunshine_update)
                        .delete(sunshine_destroy),
                )
                .route(
                    "/nutrient_requirement",
                    get(nutrient_show)
                        .post(nutrient_create)
                        .put(nutrient_update)
                        .patch(nutrient_update)
                        .delete(nutrient_destroy),
                ),
        )
}

fn temperature_json(e: &TemperatureRequirementEntity) -> Value {
    json!({
        "id": e.id,
        "crop_stage_id": e.crop_stage_id,
        "base_temperature": e.base_temperature.as_ref().map(|d| d.to_string()),
        "optimal_min": e.optimal_min.as_ref().map(|d| d.to_string()),
        "optimal_max": e.optimal_max.as_ref().map(|d| d.to_string()),
        "low_stress_threshold": e.low_stress_threshold.as_ref().map(|d| d.to_string()),
        "high_stress_threshold": e.high_stress_threshold.as_ref().map(|d| d.to_string()),
        "frost_threshold": e.frost_threshold.as_ref().map(|d| d.to_string()),
        "sterility_risk_threshold": e.sterility_risk_threshold.as_ref().map(|d| d.to_string()),
        "max_temperature": e.max_temperature.as_ref().map(|d| d.to_string()),
    })
}

fn thermal_json(e: &ThermalRequirementEntity) -> Value {
    json!({
        "id": e.id,
        "crop_stage_id": e.crop_stage_id,
        "required_gdd": e.required_gdd.as_ref().map(|d| d.to_string()),
    })
}

fn sunshine_json(e: &SunshineRequirementEntity) -> Value {
    json!({
        "id": e.id,
        "crop_stage_id": e.crop_stage_id,
        "minimum_sunshine_hours": e.minimum_sunshine_hours.as_ref().map(|d| d.to_string()),
        "target_sunshine_hours": e.target_sunshine_hours.as_ref().map(|d| d.to_string()),
    })
}

fn nutrient_json(e: &NutrientRequirementEntity) -> Value {
    json!({
        "id": e.id,
        "crop_stage_id": e.crop_stage_id,
        "daily_uptake_n": e.daily_uptake_n.as_ref().map(|d| d.to_string()),
        "daily_uptake_p": e.daily_uptake_p.as_ref().map(|d| d.to_string()),
        "daily_uptake_k": e.daily_uptake_k.as_ref().map(|d| d.to_string()),
        "region": e.region,
    })
}

fn crop_stage_requirement_internal_error() -> (StatusCode, Value) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        json!({"errors": ["internal"]}),
    )
}

fn crop_stage_requirement_internal_http_error() -> (StatusCode, Json<Value>) {
    let (status, body) = crop_stage_requirement_internal_error();
    (status, Json(body))
}

fn crop_stage_requirement_show_not_found(kind: &str) -> (StatusCode, Value) {
    (
        StatusCode::NOT_FOUND,
        json!({"errors": [format!("{kind} not found")]}),
    )
}

fn crop_stage_requirement_temperature_show_already_exists() -> (StatusCode, Value) {
    (
        StatusCode::UNPROCESSABLE_ENTITY,
        json!({"errors": ["TemperatureRequirement already exists"]}),
    )
}

fn crop_stage_requirement_write_not_found() -> (StatusCode, Value) {
    (
        StatusCode::NOT_FOUND,
        json!({"errors": ["not found"]}),
    )
}

fn crop_stage_requirement_write_already_exists() -> (StatusCode, Value) {
    (
        StatusCode::UNPROCESSABLE_ENTITY,
        json!({"errors": ["already exists"]}),
    )
}

fn crop_stage_requirement_validation_errors(errors: Vec<String>) -> (StatusCode, Value) {
    (
        StatusCode::UNPROCESSABLE_ENTITY,
        json!({"errors": errors}),
    )
}

async fn temperature_show(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    ensure_authorized_crop_stage(&state, user_id, crop_id, stage_id, false).await?;
    let pool = state.sqlite.clone();
    let req_gw = TemperatureRequirementSqliteGateway::new(pool);
    struct Port {
        status: StatusCode,
        body: Value,
    }
    impl MastersTemperatureRequirementOutputPort for Port {
        fn on_show_success(&mut self, e: TemperatureRequirementEntity) {
            self.status = StatusCode::OK;
            self.body = temperature_json(&e);
        }
        fn on_create_success(&mut self, e: TemperatureRequirementEntity) {
            self.status = StatusCode::CREATED;
            self.body = temperature_json(&e);
        }
        fn on_update_success(&mut self, e: TemperatureRequirementEntity) {
            self.status = StatusCode::OK;
            self.body = temperature_json(&e);
        }
        fn on_destroy_success(&mut self) {
            self.status = StatusCode::NO_CONTENT;
        }
        fn on_not_found(&mut self) {
            let (status, body) = crop_stage_requirement_show_not_found("TemperatureRequirement");
            self.status = status;
            self.body = body;
        }
        fn on_already_exists(&mut self) {
            let (status, body) = crop_stage_requirement_temperature_show_already_exists();
            self.status = status;
            self.body = body;
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            let (status, body) = crop_stage_requirement_validation_errors(errors);
            self.status = status;
            self.body = body;
        }
    }
    let mut port = Port {
        status: StatusCode::NOT_FOUND,
        body: json!({}),
    };
    let mut interactor = MastersTemperatureRequirementShowInteractor::new(&mut port, &req_gw);
    interactor
        .call(CropStageDetailInput {
            crop_stage_id: stage_id,
        })
        .map_err(|_| crop_stage_requirement_internal_http_error())?;
    Ok((port.status, Json(port.body)))
}

async fn temperature_create(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    temperature_write(state, auth, crop_id, stage_id, body, true).await
}

async fn temperature_update(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    temperature_write(state, auth, crop_id, stage_id, body, false).await
}

async fn temperature_write(
    state: AppState,
    auth: MastersUserId,
    crop_id: i64,
    stage_id: i64,
    body: Value,
    create: bool,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    ensure_authorized_crop_stage(&state, user_id, crop_id, stage_id, true).await?;
    let pool = state.sqlite.clone();
    let req_gw = TemperatureRequirementSqliteGateway::new(pool.clone());
    let crop_gw = CropSqliteGateway::new(pool);
    struct Port {
        status: StatusCode,
        body: Value,
    }
    impl MastersTemperatureRequirementOutputPort for Port {
        fn on_show_success(&mut self, _: TemperatureRequirementEntity) {}
        fn on_create_success(&mut self, e: TemperatureRequirementEntity) {
            self.status = StatusCode::CREATED;
            self.body = temperature_json(&e);
        }
        fn on_update_success(&mut self, e: TemperatureRequirementEntity) {
            self.status = StatusCode::OK;
            self.body = temperature_json(&e);
        }
        fn on_destroy_success(&mut self) {}
        fn on_not_found(&mut self) {
            let (status, body) = crop_stage_requirement_write_not_found();
            self.status = status;
            self.body = body;
        }
        fn on_already_exists(&mut self) {
            let (status, body) = crop_stage_requirement_write_already_exists();
            self.status = status;
            self.body = body;
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            let (status, body) = crop_stage_requirement_validation_errors(errors);
            self.status = status;
            self.body = body;
        }
    }
    let mut port = Port {
        status: StatusCode::INTERNAL_SERVER_ERROR,
        body: json!({}),
    };
    let input = TemperatureRequirementUpdateInput::new(crop_id, stage_id, body);
    if create {
        let mut interactor =
            MastersTemperatureRequirementCreateInteractor::new(&mut port, &crop_gw, &req_gw);
        interactor
            .call(input)
            .map_err(|_| crop_stage_requirement_internal_http_error())?;
    } else {
        let mut interactor =
            MastersTemperatureRequirementUpdateInteractor::new(&mut port, &crop_gw, &req_gw);
        interactor
            .call(input)
            .map_err(|_| crop_stage_requirement_internal_http_error())?;
    }
    Ok((port.status, Json(port.body)))
}

async fn temperature_destroy(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
) -> Result<StatusCode, (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    ensure_authorized_crop_stage(&state, user_id, crop_id, stage_id, true).await?;
    let pool = state.sqlite.clone();
    let crop_gw = CropSqliteGateway::new(pool);
    struct Port {
        status: StatusCode,
    }
    impl MastersTemperatureRequirementOutputPort for Port {
        fn on_show_success(&mut self, _: TemperatureRequirementEntity) {}
        fn on_create_success(&mut self, _: TemperatureRequirementEntity) {}
        fn on_update_success(&mut self, _: TemperatureRequirementEntity) {}
        fn on_destroy_success(&mut self) {
            self.status = StatusCode::NO_CONTENT;
        }
        fn on_not_found(&mut self) {
            self.status = StatusCode::NOT_FOUND;
        }
        fn on_already_exists(&mut self) {}
        fn on_validation_errors(&mut self, _: Vec<String>) {}
    }
    let mut port = Port {
        status: StatusCode::NOT_FOUND,
    };
    let mut interactor = MastersTemperatureRequirementDestroyInteractor::new(&mut port, &crop_gw);
    interactor
        .call(CropStageDetailInput {
            crop_stage_id: stage_id,
        })
        .map_err(|_| crop_stage_requirement_internal_http_error())?;
    Ok(port.status)
}

async fn thermal_show(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    ensure_authorized_crop_stage(&state, user_id, crop_id, stage_id, false).await?;
    let pool = state.sqlite.clone();
    let req_gw = ThermalRequirementSqliteGateway::new(pool);
    struct Port {
        status: StatusCode,
        body: Value,
    }
    impl MastersThermalRequirementOutputPort for Port {
        fn on_show_success(&mut self, e: ThermalRequirementEntity) {
            self.status = StatusCode::OK;
            self.body = thermal_json(&e);
        }
        fn on_create_success(&mut self, e: ThermalRequirementEntity) {
            self.status = StatusCode::CREATED;
            self.body = thermal_json(&e);
        }
        fn on_update_success(&mut self, e: ThermalRequirementEntity) {
            self.status = StatusCode::OK;
            self.body = thermal_json(&e);
        }
        fn on_destroy_success(&mut self) {
            self.status = StatusCode::NO_CONTENT;
        }
        fn on_not_found(&mut self) {
            let (status, body) = crop_stage_requirement_show_not_found("ThermalRequirement");
            self.status = status;
            self.body = body;
        }
        fn on_already_exists(&mut self) {
            let (status, body) = crop_stage_requirement_write_already_exists();
            self.status = status;
            self.body = body;
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            let (status, body) = crop_stage_requirement_validation_errors(errors);
            self.status = status;
            self.body = body;
        }
    }
    let mut port = Port {
        status: StatusCode::NOT_FOUND,
        body: json!({}),
    };
    let mut interactor = MastersThermalRequirementShowInteractor::new(&mut port, &req_gw);
    interactor
        .call(CropStageDetailInput {
            crop_stage_id: stage_id,
        })
        .map_err(|_| crop_stage_requirement_internal_http_error())?;
    Ok((port.status, Json(port.body)))
}

async fn thermal_create(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    thermal_write(state, auth, crop_id, stage_id, body, true).await
}

async fn thermal_update(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    thermal_write(state, auth, crop_id, stage_id, body, false).await
}

async fn thermal_write(
    state: AppState,
    auth: MastersUserId,
    crop_id: i64,
    stage_id: i64,
    body: Value,
    create: bool,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    ensure_authorized_crop_stage(&state, user_id, crop_id, stage_id, true).await?;
    let pool = state.sqlite.clone();
    let req_gw = ThermalRequirementSqliteGateway::new(pool.clone());
    let crop_gw = CropSqliteGateway::new(pool);
    struct Port {
        status: StatusCode,
        body: Value,
    }
    impl MastersThermalRequirementOutputPort for Port {
        fn on_show_success(&mut self, _: ThermalRequirementEntity) {}
        fn on_create_success(&mut self, e: ThermalRequirementEntity) {
            self.status = StatusCode::CREATED;
            self.body = thermal_json(&e);
        }
        fn on_update_success(&mut self, e: ThermalRequirementEntity) {
            self.status = StatusCode::OK;
            self.body = thermal_json(&e);
        }
        fn on_destroy_success(&mut self) {}
        fn on_not_found(&mut self) {
            let (status, body) = crop_stage_requirement_write_not_found();
            self.status = status;
            self.body = body;
        }
        fn on_already_exists(&mut self) {
            let (status, body) = crop_stage_requirement_write_already_exists();
            self.status = status;
            self.body = body;
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            let (status, body) = crop_stage_requirement_validation_errors(errors);
            self.status = status;
            self.body = body;
        }
    }
    let mut port = Port {
        status: StatusCode::INTERNAL_SERVER_ERROR,
        body: json!({}),
    };
    let input = ThermalRequirementUpdateInput::new(crop_id, stage_id, body);
    if create {
        let mut interactor =
            MastersThermalRequirementCreateInteractor::new(&mut port, &crop_gw, &req_gw);
        interactor
            .call(input)
            .map_err(|_| crop_stage_requirement_internal_http_error())?;
    } else {
        let mut interactor =
            MastersThermalRequirementUpdateInteractor::new(&mut port, &crop_gw, &req_gw);
        interactor
            .call(input)
            .map_err(|_| crop_stage_requirement_internal_http_error())?;
    }
    Ok((port.status, Json(port.body)))
}

async fn thermal_destroy(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
) -> Result<StatusCode, (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    ensure_authorized_crop_stage(&state, user_id, crop_id, stage_id, true).await?;
    let pool = state.sqlite.clone();
    let crop_gw = CropSqliteGateway::new(pool);
    struct Port {
        status: StatusCode,
    }
    impl MastersThermalRequirementOutputPort for Port {
        fn on_show_success(&mut self, _: ThermalRequirementEntity) {}
        fn on_create_success(&mut self, _: ThermalRequirementEntity) {}
        fn on_update_success(&mut self, _: ThermalRequirementEntity) {}
        fn on_destroy_success(&mut self) {
            self.status = StatusCode::NO_CONTENT;
        }
        fn on_not_found(&mut self) {
            self.status = StatusCode::NOT_FOUND;
        }
        fn on_already_exists(&mut self) {}
        fn on_validation_errors(&mut self, _: Vec<String>) {}
    }
    let mut port = Port {
        status: StatusCode::NOT_FOUND,
    };
    let mut interactor = MastersThermalRequirementDestroyInteractor::new(&mut port, &crop_gw);
    interactor
        .call(CropStageDetailInput {
            crop_stage_id: stage_id,
        })
        .map_err(|_| crop_stage_requirement_internal_http_error())?;
    Ok(port.status)
}

async fn sunshine_show(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    ensure_authorized_crop_stage(&state, user_id, crop_id, stage_id, false).await?;
    let pool = state.sqlite.clone();
    let req_gw = SunshineRequirementSqliteGateway::new(pool);
    struct Port {
        status: StatusCode,
        body: Value,
    }
    impl MastersSunshineRequirementOutputPort for Port {
        fn on_show_success(&mut self, e: SunshineRequirementEntity) {
            self.status = StatusCode::OK;
            self.body = sunshine_json(&e);
        }
        fn on_create_success(&mut self, e: SunshineRequirementEntity) {
            self.status = StatusCode::CREATED;
            self.body = sunshine_json(&e);
        }
        fn on_update_success(&mut self, e: SunshineRequirementEntity) {
            self.status = StatusCode::OK;
            self.body = sunshine_json(&e);
        }
        fn on_destroy_success(&mut self) {
            self.status = StatusCode::NO_CONTENT;
        }
        fn on_not_found(&mut self) {
            let (status, body) = crop_stage_requirement_write_not_found();
            self.status = status;
            self.body = body;
        }
        fn on_already_exists(&mut self) {
            let (status, body) = crop_stage_requirement_write_already_exists();
            self.status = status;
            self.body = body;
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            let (status, body) = crop_stage_requirement_validation_errors(errors);
            self.status = status;
            self.body = body;
        }
    }
    let mut port = Port {
        status: StatusCode::NOT_FOUND,
        body: json!({}),
    };
    let mut interactor = MastersSunshineRequirementShowInteractor::new(&mut port, &req_gw);
    interactor
        .call(CropStageDetailInput {
            crop_stage_id: stage_id,
        })
        .map_err(|_| crop_stage_requirement_internal_http_error())?;
    Ok((port.status, Json(port.body)))
}

async fn sunshine_create(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    sunshine_write(state, auth, crop_id, stage_id, body, true).await
}

async fn sunshine_update(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    sunshine_write(state, auth, crop_id, stage_id, body, false).await
}

async fn sunshine_write(
    state: AppState,
    auth: MastersUserId,
    crop_id: i64,
    stage_id: i64,
    body: Value,
    create: bool,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    ensure_authorized_crop_stage(&state, user_id, crop_id, stage_id, true).await?;
    let pool = state.sqlite.clone();
    let req_gw = SunshineRequirementSqliteGateway::new(pool.clone());
    let crop_gw = CropSqliteGateway::new(pool);
    struct Port {
        status: StatusCode,
        body: Value,
    }
    impl MastersSunshineRequirementOutputPort for Port {
        fn on_show_success(&mut self, _: SunshineRequirementEntity) {}
        fn on_create_success(&mut self, e: SunshineRequirementEntity) {
            self.status = StatusCode::CREATED;
            self.body = sunshine_json(&e);
        }
        fn on_update_success(&mut self, e: SunshineRequirementEntity) {
            self.status = StatusCode::OK;
            self.body = sunshine_json(&e);
        }
        fn on_destroy_success(&mut self) {}
        fn on_not_found(&mut self) {
            let (status, body) = crop_stage_requirement_write_not_found();
            self.status = status;
            self.body = body;
        }
        fn on_already_exists(&mut self) {
            let (status, body) = crop_stage_requirement_write_already_exists();
            self.status = status;
            self.body = body;
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            let (status, body) = crop_stage_requirement_validation_errors(errors);
            self.status = status;
            self.body = body;
        }
    }
    let mut port = Port {
        status: StatusCode::INTERNAL_SERVER_ERROR,
        body: json!({}),
    };
    let input = SunshineRequirementUpdateInput::new(crop_id, stage_id, body);
    if create {
        let mut interactor =
            MastersSunshineRequirementCreateInteractor::new(&mut port, &crop_gw, &req_gw);
        interactor
            .call(input)
            .map_err(|_| crop_stage_requirement_internal_http_error())?;
    } else {
        let mut interactor =
            MastersSunshineRequirementUpdateInteractor::new(&mut port, &crop_gw, &req_gw);
        interactor
            .call(input)
            .map_err(|_| crop_stage_requirement_internal_http_error())?;
    }
    Ok((port.status, Json(port.body)))
}

async fn sunshine_destroy(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
) -> Result<StatusCode, (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    ensure_authorized_crop_stage(&state, user_id, crop_id, stage_id, true).await?;
    let pool = state.sqlite.clone();
    let crop_gw = CropSqliteGateway::new(pool);
    struct Port {
        status: StatusCode,
    }
    impl MastersSunshineRequirementOutputPort for Port {
        fn on_show_success(&mut self, _: SunshineRequirementEntity) {}
        fn on_create_success(&mut self, _: SunshineRequirementEntity) {}
        fn on_update_success(&mut self, _: SunshineRequirementEntity) {}
        fn on_destroy_success(&mut self) {
            self.status = StatusCode::NO_CONTENT;
        }
        fn on_not_found(&mut self) {
            self.status = StatusCode::NOT_FOUND;
        }
        fn on_already_exists(&mut self) {}
        fn on_validation_errors(&mut self, _: Vec<String>) {}
    }
    let mut port = Port {
        status: StatusCode::NOT_FOUND,
    };
    let mut interactor = MastersSunshineRequirementDestroyInteractor::new(&mut port, &crop_gw);
    interactor
        .call(CropStageDetailInput {
            crop_stage_id: stage_id,
        })
        .map_err(|_| crop_stage_requirement_internal_http_error())?;
    Ok(port.status)
}

async fn nutrient_show(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    ensure_authorized_crop_stage(&state, user_id, crop_id, stage_id, false).await?;
    let pool = state.sqlite.clone();
    let req_gw = NutrientRequirementSqliteGateway::new(pool);
    struct Port {
        status: StatusCode,
        body: Value,
    }
    impl MastersNutrientRequirementOutputPort for Port {
        fn on_show_success(&mut self, e: NutrientRequirementEntity) {
            self.status = StatusCode::OK;
            self.body = nutrient_json(&e);
        }
        fn on_create_success(&mut self, e: NutrientRequirementEntity) {
            self.status = StatusCode::CREATED;
            self.body = nutrient_json(&e);
        }
        fn on_update_success(&mut self, e: NutrientRequirementEntity) {
            self.status = StatusCode::OK;
            self.body = nutrient_json(&e);
        }
        fn on_destroy_success(&mut self) {
            self.status = StatusCode::NO_CONTENT;
        }
        fn on_not_found(&mut self) {
            let (status, body) = crop_stage_requirement_write_not_found();
            self.status = status;
            self.body = body;
        }
        fn on_already_exists(&mut self) {
            let (status, body) = crop_stage_requirement_write_already_exists();
            self.status = status;
            self.body = body;
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            let (status, body) = crop_stage_requirement_validation_errors(errors);
            self.status = status;
            self.body = body;
        }
    }
    let mut port = Port {
        status: StatusCode::NOT_FOUND,
        body: json!({}),
    };
    let mut interactor = MastersNutrientRequirementShowInteractor::new(&mut port, &req_gw);
    interactor
        .call(CropStageDetailInput {
            crop_stage_id: stage_id,
        })
        .map_err(|_| crop_stage_requirement_internal_http_error())?;
    Ok((port.status, Json(port.body)))
}

async fn nutrient_create(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    nutrient_write(state, auth, crop_id, stage_id, body, true).await
}

async fn nutrient_update(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    nutrient_write(state, auth, crop_id, stage_id, body, false).await
}

async fn nutrient_write(
    state: AppState,
    auth: MastersUserId,
    crop_id: i64,
    stage_id: i64,
    body: Value,
    create: bool,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    ensure_authorized_crop_stage(&state, user_id, crop_id, stage_id, true).await?;
    let pool = state.sqlite.clone();
    let req_gw = NutrientRequirementSqliteGateway::new(pool.clone());
    let crop_gw = CropSqliteGateway::new(pool);
    struct Port {
        status: StatusCode,
        body: Value,
    }
    impl MastersNutrientRequirementOutputPort for Port {
        fn on_show_success(&mut self, _: NutrientRequirementEntity) {}
        fn on_create_success(&mut self, e: NutrientRequirementEntity) {
            self.status = StatusCode::CREATED;
            self.body = nutrient_json(&e);
        }
        fn on_update_success(&mut self, e: NutrientRequirementEntity) {
            self.status = StatusCode::OK;
            self.body = nutrient_json(&e);
        }
        fn on_destroy_success(&mut self) {}
        fn on_not_found(&mut self) {
            let (status, body) = crop_stage_requirement_write_not_found();
            self.status = status;
            self.body = body;
        }
        fn on_already_exists(&mut self) {
            let (status, body) = crop_stage_requirement_write_already_exists();
            self.status = status;
            self.body = body;
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            let (status, body) = crop_stage_requirement_validation_errors(errors);
            self.status = status;
            self.body = body;
        }
    }
    let mut port = Port {
        status: StatusCode::INTERNAL_SERVER_ERROR,
        body: json!({}),
    };
    let input = NutrientRequirementUpdateInput::new(crop_id, stage_id, body);
    if create {
        let mut interactor =
            MastersNutrientRequirementCreateInteractor::new(&mut port, &crop_gw, &req_gw);
        interactor
            .call(input)
            .map_err(|_| crop_stage_requirement_internal_http_error())?;
    } else {
        let mut interactor =
            MastersNutrientRequirementUpdateInteractor::new(&mut port, &crop_gw, &req_gw);
        interactor
            .call(input)
            .map_err(|_| crop_stage_requirement_internal_http_error())?;
    }
    Ok((port.status, Json(port.body)))
}

async fn nutrient_destroy(
    State(state): State<AppState>,
    auth: MastersUserId,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
) -> Result<StatusCode, (StatusCode, Json<Value>)> {
    let user_id = auth.0;
    ensure_authorized_crop_stage(&state, user_id, crop_id, stage_id, true).await?;
    let pool = state.sqlite.clone();
    let crop_gw = CropSqliteGateway::new(pool);
    struct Port {
        status: StatusCode,
    }
    impl MastersNutrientRequirementOutputPort for Port {
        fn on_show_success(&mut self, _: NutrientRequirementEntity) {}
        fn on_create_success(&mut self, _: NutrientRequirementEntity) {}
        fn on_update_success(&mut self, _: NutrientRequirementEntity) {}
        fn on_destroy_success(&mut self) {
            self.status = StatusCode::NO_CONTENT;
        }
        fn on_not_found(&mut self) {
            self.status = StatusCode::NOT_FOUND;
        }
        fn on_already_exists(&mut self) {}
        fn on_validation_errors(&mut self, _: Vec<String>) {}
    }
    let mut port = Port {
        status: StatusCode::NOT_FOUND,
    };
    let mut interactor = MastersNutrientRequirementDestroyInteractor::new(&mut port, &crop_gw);
    interactor
        .call(CropStageDetailInput {
            crop_stage_id: stage_id,
        })
        .map_err(|_| crop_stage_requirement_internal_http_error())?;
    Ok(port.status)
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::crop::entities::{
        NutrientRequirementEntity, SunshineRequirementEntity, TemperatureRequirementEntity,
        ThermalRequirementEntity,
    };
    use rust_decimal::Decimal;

    #[test]
    fn temperature_show_not_found_maps_to_404_with_kind_label() {
        let (status, body) = crop_stage_requirement_show_not_found("TemperatureRequirement");
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert_eq!(body["errors"][0], "TemperatureRequirement not found");
    }

    #[test]
    fn thermal_show_not_found_maps_to_404_with_kind_label() {
        let (status, body) = crop_stage_requirement_show_not_found("ThermalRequirement");
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert_eq!(body["errors"][0], "ThermalRequirement not found");
    }

    #[test]
    fn temperature_show_already_exists_maps_to_422_with_specific_message() {
        let (status, body) = crop_stage_requirement_temperature_show_already_exists();
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(body["errors"][0], "TemperatureRequirement already exists");
    }

    #[test]
    fn requirement_write_not_found_maps_to_404() {
        let (status, body) = crop_stage_requirement_write_not_found();
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert_eq!(body["errors"][0], "not found");
    }

    #[test]
    fn requirement_write_already_exists_maps_to_422() {
        let (status, body) = crop_stage_requirement_write_already_exists();
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(body["errors"][0], "already exists");
    }

    #[test]
    fn requirement_validation_errors_preserves_messages() {
        let (status, body) =
            crop_stage_requirement_validation_errors(vec!["base_temperature invalid".into()]);
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(body["errors"][0], "base_temperature invalid");
    }

    #[test]
    fn requirement_internal_error_maps_to_500() {
        let (status, body) = crop_stage_requirement_internal_error();
        assert_eq!(status, StatusCode::INTERNAL_SERVER_ERROR);
        assert_eq!(body["errors"][0], "internal");
    }

    #[test]
    fn temperature_json_serializes_decimal_fields_as_strings() {
        let entity = TemperatureRequirementEntity {
            id: 1,
            crop_stage_id: 9,
            base_temperature: Some(Decimal::new(105, 1)),
            optimal_min: None,
            optimal_max: None,
            low_stress_threshold: None,
            high_stress_threshold: None,
            frost_threshold: None,
            sterility_risk_threshold: None,
            max_temperature: None,
        };
        let body = temperature_json(&entity);
        assert_eq!(body["id"], 1);
        assert_eq!(body["crop_stage_id"], 9);
        assert_eq!(body["base_temperature"], "10.5");
        assert!(body.get("optimal_min").unwrap().is_null());
    }

    #[test]
    fn thermal_json_serializes_required_gdd() {
        let entity = ThermalRequirementEntity {
            id: 2,
            crop_stage_id: 3,
            required_gdd: Some(Decimal::new(1200, 0)),
        };
        let body = thermal_json(&entity);
        assert_eq!(body["required_gdd"], "1200");
    }

    #[test]
    fn sunshine_json_serializes_hour_fields() {
        let entity = SunshineRequirementEntity {
            id: 4,
            crop_stage_id: 5,
            minimum_sunshine_hours: Some(Decimal::new(6, 0)),
            target_sunshine_hours: Some(Decimal::new(8, 0)),
        };
        let body = sunshine_json(&entity);
        assert_eq!(body["minimum_sunshine_hours"], "6");
        assert_eq!(body["target_sunshine_hours"], "8");
    }

    #[test]
    fn nutrient_json_includes_region() {
        let entity = NutrientRequirementEntity {
            id: 6,
            crop_stage_id: 7,
            daily_uptake_n: Some(Decimal::new(15, 1)),
            daily_uptake_p: None,
            daily_uptake_k: None,
            region: Some("jp".into()),
        };
        let body = nutrient_json(&entity);
        assert_eq!(body["region"], "jp");
        assert_eq!(body["daily_uptake_n"], "1.5");
    }
}