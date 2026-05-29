//! Nested crop stage requirements under masters crops.

use crate::masters_crop_stages::ensure_crop_visible;
use crate::session_auth::user_id_from_session;
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
use axum_extra::extract::cookie::CookieJar;
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
                        .delete(temperature_destroy),
                )
                .route(
                    "/thermal_requirement",
                    get(thermal_show)
                        .post(thermal_create)
                        .put(thermal_update)
                        .delete(thermal_destroy),
                )
                .route(
                    "/sunshine_requirement",
                    get(sunshine_show)
                        .post(sunshine_create)
                        .put(sunshine_update)
                        .delete(sunshine_destroy),
                )
                .route(
                    "/nutrient_requirement",
                    get(nutrient_show)
                        .post(nutrient_create)
                        .put(nutrient_update)
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
        "required_gdd": e.required_gdd.to_string(),
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

async fn temperature_show(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
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
            self.status = StatusCode::NOT_FOUND;
            self.body = json!({"error": "TemperatureRequirement not found"});
        }
        fn on_already_exists(&mut self) {
            self.status = StatusCode::UNPROCESSABLE_ENTITY;
            self.body = json!({"error": "TemperatureRequirement already exists"});
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            self.status = StatusCode::UNPROCESSABLE_ENTITY;
            self.body = json!({"errors": errors});
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
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    Ok((port.status, Json(port.body)))
}

async fn temperature_create(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    temperature_write(state, jar, crop_id, stage_id, body, true).await
}

async fn temperature_update(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    temperature_write(state, jar, crop_id, stage_id, body, false).await
}

async fn temperature_write(
    state: AppState,
    jar: CookieJar,
    crop_id: i64,
    stage_id: i64,
    body: Value,
    create: bool,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
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
            self.status = StatusCode::NOT_FOUND;
            self.body = json!({"error": "not found"});
        }
        fn on_already_exists(&mut self) {
            self.status = StatusCode::UNPROCESSABLE_ENTITY;
            self.body = json!({"error": "already exists"});
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            self.status = StatusCode::UNPROCESSABLE_ENTITY;
            self.body = json!({"errors": errors});
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
            .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    } else {
        let mut interactor =
            MastersTemperatureRequirementUpdateInteractor::new(&mut port, &crop_gw, &req_gw);
        interactor
            .call(input)
            .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    }
    Ok((port.status, Json(port.body)))
}

async fn temperature_destroy(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
) -> Result<StatusCode, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
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
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    Ok(port.status)
}

async fn thermal_show(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
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
            self.status = StatusCode::NOT_FOUND;
            self.body = json!({"error": "ThermalRequirement not found"});
        }
        fn on_already_exists(&mut self) {
            self.status = StatusCode::UNPROCESSABLE_ENTITY;
            self.body = json!({"error": "already exists"});
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            self.status = StatusCode::UNPROCESSABLE_ENTITY;
            self.body = json!({"errors": errors});
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
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    Ok((port.status, Json(port.body)))
}

async fn thermal_create(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    thermal_write(state, jar, crop_id, stage_id, body, true).await
}

async fn thermal_update(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    thermal_write(state, jar, crop_id, stage_id, body, false).await
}

async fn thermal_write(
    state: AppState,
    jar: CookieJar,
    crop_id: i64,
    stage_id: i64,
    body: Value,
    create: bool,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
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
            self.status = StatusCode::NOT_FOUND;
            self.body = json!({"error": "not found"});
        }
        fn on_already_exists(&mut self) {
            self.status = StatusCode::UNPROCESSABLE_ENTITY;
            self.body = json!({"error": "already exists"});
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            self.status = StatusCode::UNPROCESSABLE_ENTITY;
            self.body = json!({"errors": errors});
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
            .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    } else {
        let mut interactor =
            MastersThermalRequirementUpdateInteractor::new(&mut port, &crop_gw, &req_gw);
        interactor
            .call(input)
            .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    }
    Ok((port.status, Json(port.body)))
}

async fn thermal_destroy(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
) -> Result<StatusCode, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
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
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    Ok(port.status)
}

async fn sunshine_show(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
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
            self.status = StatusCode::NOT_FOUND;
            self.body = json!({"error": "not found"});
        }
        fn on_already_exists(&mut self) {
            self.status = StatusCode::UNPROCESSABLE_ENTITY;
            self.body = json!({"error": "already exists"});
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            self.status = StatusCode::UNPROCESSABLE_ENTITY;
            self.body = json!({"errors": errors});
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
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    Ok((port.status, Json(port.body)))
}

async fn sunshine_create(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    sunshine_write(state, jar, crop_id, stage_id, body, true).await
}

async fn sunshine_update(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    sunshine_write(state, jar, crop_id, stage_id, body, false).await
}

async fn sunshine_write(
    state: AppState,
    jar: CookieJar,
    crop_id: i64,
    stage_id: i64,
    body: Value,
    create: bool,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
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
            self.status = StatusCode::NOT_FOUND;
            self.body = json!({"error": "not found"});
        }
        fn on_already_exists(&mut self) {
            self.status = StatusCode::UNPROCESSABLE_ENTITY;
            self.body = json!({"error": "already exists"});
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            self.status = StatusCode::UNPROCESSABLE_ENTITY;
            self.body = json!({"errors": errors});
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
            .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    } else {
        let mut interactor =
            MastersSunshineRequirementUpdateInteractor::new(&mut port, &crop_gw, &req_gw);
        interactor
            .call(input)
            .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    }
    Ok((port.status, Json(port.body)))
}

async fn sunshine_destroy(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
) -> Result<StatusCode, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
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
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    Ok(port.status)
}

async fn nutrient_show(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
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
            self.status = StatusCode::NOT_FOUND;
            self.body = json!({"error": "not found"});
        }
        fn on_already_exists(&mut self) {
            self.status = StatusCode::UNPROCESSABLE_ENTITY;
            self.body = json!({"error": "already exists"});
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            self.status = StatusCode::UNPROCESSABLE_ENTITY;
            self.body = json!({"errors": errors});
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
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    Ok((port.status, Json(port.body)))
}

async fn nutrient_create(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    nutrient_write(state, jar, crop_id, stage_id, body, true).await
}

async fn nutrient_update(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
    Json(body): Json<Value>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    nutrient_write(state, jar, crop_id, stage_id, body, false).await
}

async fn nutrient_write(
    state: AppState,
    jar: CookieJar,
    crop_id: i64,
    stage_id: i64,
    body: Value,
    create: bool,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
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
            self.status = StatusCode::NOT_FOUND;
            self.body = json!({"error": "not found"});
        }
        fn on_already_exists(&mut self) {
            self.status = StatusCode::UNPROCESSABLE_ENTITY;
            self.body = json!({"error": "already exists"});
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            self.status = StatusCode::UNPROCESSABLE_ENTITY;
            self.body = json!({"errors": errors});
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
            .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    } else {
        let mut interactor =
            MastersNutrientRequirementUpdateInteractor::new(&mut port, &crop_gw, &req_gw);
        interactor
            .call(input)
            .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    }
    Ok((port.status, Json(port.body)))
}

async fn nutrient_destroy(
    State(state): State<AppState>,
    jar: CookieJar,
    Path((crop_id, stage_id)): Path<(i64, i64)>,
) -> Result<StatusCode, (StatusCode, Json<Value>)> {
    let user_id = user_id_from_session(&state, &jar)
        .map_err(|s| (s, Json(json!({"error": "unauthorized"}))))?;
    ensure_crop_visible(&state, user_id, crop_id).await?;
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
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": "internal"}))))?;
    Ok(port.status)
}
