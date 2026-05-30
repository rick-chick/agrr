//! Internal farm weather API (`Api::V1::InternalController` parity).

use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde_json::{json, Value};

use crate::adapters::{PassthroughTranslator, SystemClock};
use crate::farm_weather_fetch::StartFarmWeatherFetchAdapter;
use crate::runtime_env;
use crate::state::AppState;
use agrr_adapters_sqlite::{
    InternalFarmWeatherReadSqliteGateway, InternalWeatherFetchStartSqliteGateway,
};
use agrr_domain::shared::ports::{ClockPort, TranslatorPort};
use agrr_domain::weather_data::dtos::{
    InternalFarmWeatherDataListOutput, InternalFarmWeatherFetchFailure,
    InternalFarmWeatherHttpStatus, InternalFarmWeatherReadInput, InternalFarmWeatherStatusOutput,
    InternalWeatherFetchFailure, InternalWeatherFetchHttpStatus, InternalWeatherFetchStartInput,
    InternalWeatherFetchStartOutput, InternalWeatherFetchStartVariant,
};
use agrr_domain::weather_data::interactors::{
    InternalFarmWeatherDataListInteractor, InternalFarmWeatherStatusInteractor,
    InternalWeatherFetchStartInteractor,
};
use agrr_domain::weather_data::ports::{
    InternalFarmWeatherDataListOutputPort, InternalFarmWeatherStatusOutputPort,
    InternalWeatherFetchStartOutputPort,
};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/internal/farms/{farm_id}/fetch_weather_data",
            post(fetch_weather_data),
        )
        .route(
            "/api/v1/internal/farms/{farm_id}/weather_status",
            get(weather_status),
        )
        .route(
            "/api/v1/internal/farms/{farm_id}/weather_data",
            get(get_weather_data),
        )
}

async fn ensure_internal_env() -> Result<(), (StatusCode, Json<Value>)> {
    if runtime_env::dev_environment_allowed() {
        Ok(())
    } else {
        let translator = PassthroughTranslator;
        let message = translator.t("api.errors.common.env_only", &Default::default());
        Err((
            StatusCode::FORBIDDEN,
            Json(json!({ "error": message })),
        ))
    }
}

async fn fetch_weather_data(
    State(state): State<AppState>,
    Path(farm_id): Path<String>,
) -> impl IntoResponse {
    if let Err(resp) = ensure_internal_env().await {
        return resp.into_response();
    }

    let gateway = InternalWeatherFetchStartSqliteGateway::new(state.sqlite.clone());
    let start_fetch = StartFarmWeatherFetchAdapter::new(state.clone());
    let translator = PassthroughTranslator;
    let clock = SystemClock;
    let today = clock.today();
    let mut presenter = FetchStartPresenter::default();
    let mut interactor = InternalWeatherFetchStartInteractor::new(
        &mut presenter,
        &gateway,
        &translator,
        &start_fetch,
        today,
    );
    interactor.call(InternalWeatherFetchStartInput { farm_id });
    presenter.into_response()
}

async fn weather_status(
    State(state): State<AppState>,
    Path(farm_id): Path<String>,
) -> impl IntoResponse {
    if let Err(resp) = ensure_internal_env().await {
        return resp.into_response();
    }

    let gateway = InternalFarmWeatherReadSqliteGateway::new(state.sqlite.clone());
    let translator = PassthroughTranslator;
    let mut presenter = WeatherStatusPresenter::default();
    let mut interactor =
        InternalFarmWeatherStatusInteractor::new(&mut presenter, &gateway, &translator);
    interactor.call(InternalFarmWeatherReadInput { farm_id });
    presenter.into_response()
}

async fn get_weather_data(
    State(state): State<AppState>,
    Path(farm_id): Path<String>,
) -> impl IntoResponse {
    if let Err(resp) = ensure_internal_env().await {
        return resp.into_response();
    }

    let gateway = InternalFarmWeatherReadSqliteGateway::new(state.sqlite.clone());
    let translator = PassthroughTranslator;
    let mut presenter = WeatherDataListPresenter::default();
    let mut interactor =
        InternalFarmWeatherDataListInteractor::new(&mut presenter, &gateway, &translator);
    interactor.call(InternalFarmWeatherReadInput { farm_id });
    presenter.into_response()
}

#[derive(Default)]
struct FetchStartPresenter {
    body: Option<(StatusCode, Value)>,
}

impl InternalWeatherFetchStartOutputPort for FetchStartPresenter {
    fn on_success(&mut self, dto: InternalWeatherFetchStartOutput) {
        let translator = PassthroughTranslator;
        let mut base = json!({
            "success": true,
            "farm_id": dto.farm_id,
            "status": dto.weather_data_status,
        });
        let message_key = match dto.variant {
            InternalWeatherFetchStartVariant::AlreadyCompleted => {
                base["weather_data_count"] = json!(dto.weather_data_count);
                "api.messages.common.weather_data_already_exists"
            }
            InternalWeatherFetchStartVariant::FetchStarted => {
                base["total_blocks"] = json!(dto.total_blocks);
                "api.messages.common.weather_data_fetch_started"
            }
        };
        base["message"] = json!(translator.t(message_key, &Default::default()));
        self.body = Some((StatusCode::OK, base));
    }

    fn on_failure(&mut self, dto: InternalWeatherFetchFailure) {
        let status = match dto.http_status {
            InternalWeatherFetchHttpStatus::NotFound => StatusCode::NOT_FOUND,
            InternalWeatherFetchHttpStatus::InternalServerError => {
                StatusCode::INTERNAL_SERVER_ERROR
            }
        };
        self.body = Some((status, json!({ "error": dto.message })));
    }
}

impl FetchStartPresenter {
    fn into_response(self) -> axum::response::Response {
        match self.body {
            Some((status, json)) => (status, Json(json)).into_response(),
            None => (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "error": "internal" })),
            )
                .into_response(),
        }
    }
}

#[derive(Default)]
struct WeatherStatusPresenter {
    body: Option<(StatusCode, Value)>,
}

impl InternalFarmWeatherStatusOutputPort for WeatherStatusPresenter {
    fn on_success(&mut self, dto: InternalFarmWeatherStatusOutput) {
        self.body = Some((
            StatusCode::OK,
            json!({
                "success": true,
                "farm_id": dto.farm_id,
                "status": dto.status,
                "progress": dto.progress,
                "fetched_blocks": dto.fetched_blocks,
                "total_blocks": dto.total_blocks,
                "weather_data_count": dto.weather_data_count,
                "last_error": dto.last_error,
            }),
        ));
    }

    fn on_failure(&mut self, dto: InternalFarmWeatherFetchFailure) {
        let status = match dto.http_status {
            InternalFarmWeatherHttpStatus::NotFound => StatusCode::NOT_FOUND,
        };
        self.body = Some((status, json!({ "error": dto.message })));
    }
}

impl WeatherStatusPresenter {
    fn into_response(self) -> axum::response::Response {
        match self.body {
            Some((status, json)) => (status, Json(json)).into_response(),
            None => (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "error": "internal" })),
            )
                .into_response(),
        }
    }
}

#[derive(Default)]
struct WeatherDataListPresenter {
    body: Option<(StatusCode, Value)>,
}

impl InternalFarmWeatherDataListOutputPort for WeatherDataListPresenter {
    fn on_success(&mut self, dto: InternalFarmWeatherDataListOutput) {
        self.body = Some((
            StatusCode::OK,
            json!({
                "success": true,
                "farm": dto.farm_summary,
                "weather_location": dto.weather_location_summary,
                "weather_data": dto.weather_data_rows,
                "count": dto.count,
            }),
        ));
    }

    fn on_failure(&mut self, dto: InternalFarmWeatherFetchFailure) {
        let status = match dto.http_status {
            InternalFarmWeatherHttpStatus::NotFound => StatusCode::NOT_FOUND,
        };
        self.body = Some((status, json!({ "error": dto.message })));
    }
}

impl WeatherDataListPresenter {
    fn into_response(self) -> axum::response::Response {
        match self.body {
            Some((status, json)) => (status, Json(json)).into_response(),
            None => (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "error": "internal" })),
            )
                .into_response(),
        }
    }
}
