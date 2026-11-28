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
    WeatherDataGatewayBundle,
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
            Json(json!({ "errors": [message]})),
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

    let pool = state.sqlite.clone();
    let weather_bundle = match WeatherDataGatewayBundle::resolve(pool.clone()) {
        Ok(bundle) => bundle,
        Err(e) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "errors": [e.to_string()]})),
            )
                .into_response();
        }
    };
    let gateway = InternalWeatherFetchStartSqliteGateway::new(pool, &weather_bundle);
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

    let pool = state.sqlite.clone();
    let weather_bundle = match WeatherDataGatewayBundle::resolve(pool.clone()) {
        Ok(bundle) => bundle,
        Err(e) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "errors": [e.to_string()]})),
            )
                .into_response();
        }
    };
    let gateway = InternalFarmWeatherReadSqliteGateway::new(pool, &weather_bundle);
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

    let pool = state.sqlite.clone();
    let weather_bundle = match WeatherDataGatewayBundle::resolve(pool.clone()) {
        Ok(bundle) => bundle,
        Err(e) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "errors": [e.to_string()]})),
            )
                .into_response();
        }
    };
    let gateway = InternalFarmWeatherReadSqliteGateway::new(pool, &weather_bundle);
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
        self.body = Some((status, json!({ "errors": [dto.message]})));
    }
}

impl FetchStartPresenter {
    fn into_response(self) -> axum::response::Response {
        match self.body {
            Some((status, json)) => (status, Json(json)).into_response(),
            None => (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "errors": ["internal"] })),
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
            InternalFarmWeatherHttpStatus::InternalServerError => {
                StatusCode::INTERNAL_SERVER_ERROR
            }
        };
        self.body = Some((status, json!({ "errors": [dto.message]})));
    }
}

impl WeatherStatusPresenter {
    fn into_response(self) -> axum::response::Response {
        match self.body {
            Some((status, json)) => (status, Json(json)).into_response(),
            None => (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "errors": ["internal"] })),
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
            InternalFarmWeatherHttpStatus::InternalServerError => {
                StatusCode::INTERNAL_SERVER_ERROR
            }
        };
        self.body = Some((status, json!({ "errors": [dto.message]})));
    }
}

impl WeatherDataListPresenter {
    fn into_response(self) -> axum::response::Response {
        match self.body {
            Some((status, json)) => (status, Json(json)).into_response(),
            None => (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "errors": ["internal"] })),
            )
                .into_response(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::weather_data::dtos::{
        InternalFarmWeatherDataListOutput, InternalFarmWeatherFetchFailure,
        InternalFarmWeatherHttpStatus, InternalFarmWeatherStatusOutput,
        InternalWeatherFetchFailure, InternalWeatherFetchHttpStatus,
        InternalWeatherFetchStartOutput, InternalWeatherFetchStartVariant,
    };
    use agrr_domain::weather_data::ports::{
        InternalFarmWeatherDataListOutputPort, InternalFarmWeatherStatusOutputPort,
        InternalWeatherFetchStartOutputPort,
    };

    #[test]
    fn fetch_start_presenter_maps_already_completed_with_count() {
        let mut presenter = FetchStartPresenter::default();
        presenter.on_success(InternalWeatherFetchStartOutput {
            variant: InternalWeatherFetchStartVariant::AlreadyCompleted,
            farm_id: 42,
            weather_data_status: "completed".into(),
            weather_data_count: Some(365),
            total_blocks: 0,
        });
        let (status, body) = presenter.body.expect("body");
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body["success"], true);
        assert_eq!(body["farm_id"], 42);
        assert_eq!(body["status"], "completed");
        assert_eq!(body["weather_data_count"], 365);
        assert!(body.get("total_blocks").is_none());
        assert!(body.get("message").is_some());
    }

    #[test]
    fn fetch_start_presenter_maps_fetch_started_with_total_blocks() {
        let mut presenter = FetchStartPresenter::default();
        presenter.on_success(InternalWeatherFetchStartOutput {
            variant: InternalWeatherFetchStartVariant::FetchStarted,
            farm_id: 7,
            weather_data_status: "fetching".into(),
            weather_data_count: None,
            total_blocks: 12,
        });
        let (status, body) = presenter.body.expect("body");
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body["success"], true);
        assert_eq!(body["farm_id"], 7);
        assert_eq!(body["status"], "fetching");
        assert_eq!(body["total_blocks"], 12);
        assert!(body.get("weather_data_count").is_none());
        assert!(body.get("message").is_some());
    }

    #[test]
    fn fetch_start_presenter_failure_maps_not_found_and_internal_error() {
        let mut not_found = FetchStartPresenter::default();
        not_found.on_failure(InternalWeatherFetchFailure {
            message: "farm missing".into(),
            http_status: InternalWeatherFetchHttpStatus::NotFound,
        });
        let (status, body) = not_found.body.expect("body");
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert_eq!(body["errors"][0], "farm missing");

        let mut internal = FetchStartPresenter::default();
        internal.on_failure(InternalWeatherFetchFailure {
            message: "sqlite down".into(),
            http_status: InternalWeatherFetchHttpStatus::InternalServerError,
        });
        let (status, body) = internal.body.expect("body");
        assert_eq!(status, StatusCode::INTERNAL_SERVER_ERROR);
        assert_eq!(body["errors"][0], "sqlite down");
    }

    #[test]
    fn weather_status_presenter_maps_success_payload() {
        let mut presenter = WeatherStatusPresenter::default();
        presenter.on_success(InternalFarmWeatherStatusOutput {
            farm_id: 3,
            status: "fetching".into(),
            progress: 50,
            fetched_blocks: 6,
            total_blocks: 12,
            weather_data_count: 180,
            last_error: Some("transient".into()),
        });
        let (status, body) = presenter.body.expect("body");
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body["success"], true);
        assert_eq!(body["farm_id"], 3);
        assert_eq!(body["status"], "fetching");
        assert_eq!(body["progress"], 50);
        assert_eq!(body["fetched_blocks"], 6);
        assert_eq!(body["total_blocks"], 12);
        assert_eq!(body["weather_data_count"], 180);
        assert_eq!(body["last_error"], "transient");
    }

    #[test]
    fn weather_status_presenter_failure_maps_http_status() {
        let mut presenter = WeatherStatusPresenter::default();
        presenter.on_failure(InternalFarmWeatherFetchFailure {
            message: "no farm".into(),
            http_status: InternalFarmWeatherHttpStatus::NotFound,
        });
        let (status, body) = presenter.body.expect("body");
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert_eq!(body["errors"][0], "no farm");
    }

    #[test]
    fn weather_data_list_presenter_maps_success_and_count() {
        let rows = vec![json!({"date": "2026-01-01"}), json!({"date": "2026-01-02"})];
        let mut presenter = WeatherDataListPresenter::default();
        presenter.on_success(InternalFarmWeatherDataListOutput {
            farm_summary: json!({"id": 1, "name": "North"}),
            weather_location_summary: json!({"lat": 35.0}),
            weather_data_rows: rows.clone(),
            count: 2,
        });
        let (status, body) = presenter.body.expect("body");
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body["success"], true);
        assert_eq!(body["farm"]["name"], "North");
        assert_eq!(body["weather_location"]["lat"], 35.0);
        let weather_data = body["weather_data"].as_array().expect("weather_data array");
        assert_eq!(weather_data.len(), 2);
        assert_eq!(weather_data[0]["date"], "2026-01-01");
        assert_eq!(weather_data[1]["date"], "2026-01-02");
        assert_eq!(body["count"], 2);
    }

    #[test]
    fn weather_data_list_presenter_failure_maps_internal_error() {
        let mut presenter = WeatherDataListPresenter::default();
        presenter.on_failure(InternalFarmWeatherFetchFailure {
            message: "storage".into(),
            http_status: InternalFarmWeatherHttpStatus::InternalServerError,
        });
        let (status, body) = presenter.body.expect("body");
        assert_eq!(status, StatusCode::INTERNAL_SERVER_ERROR);
        assert_eq!(body["errors"][0], "storage");
    }

    #[test]
    fn weather_data_list_presenter_failure_maps_not_found() {
        let mut presenter = WeatherDataListPresenter::default();
        presenter.on_failure(InternalFarmWeatherFetchFailure {
            message: "farm absent".into(),
            http_status: InternalFarmWeatherHttpStatus::NotFound,
        });
        let (status, body) = presenter.body.expect("body");
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert_eq!(body["errors"][0], "farm absent");
    }

    #[test]
    fn weather_status_presenter_failure_maps_internal_error() {
        let mut presenter = WeatherStatusPresenter::default();
        presenter.on_failure(InternalFarmWeatherFetchFailure {
            message: "read failed".into(),
            http_status: InternalFarmWeatherHttpStatus::InternalServerError,
        });
        let (status, body) = presenter.body.expect("body");
        assert_eq!(status, StatusCode::INTERNAL_SERVER_ERROR);
        assert_eq!(body["errors"][0], "read failed");
    }

    #[test]
    fn weather_status_presenter_success_serializes_null_last_error() {
        let mut presenter = WeatherStatusPresenter::default();
        presenter.on_success(InternalFarmWeatherStatusOutput {
            farm_id: 9,
            status: "completed".into(),
            progress: 100,
            fetched_blocks: 12,
            total_blocks: 12,
            weather_data_count: 400,
            last_error: None,
        });
        let (status, body) = presenter.body.expect("body");
        assert_eq!(status, StatusCode::OK);
        assert!(body["last_error"].is_null());
    }

    #[tokio::test]
    async fn presenter_into_response_without_body_returns_internal_error_contract() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        for response in [
            FetchStartPresenter::default().into_response(),
            WeatherStatusPresenter::default().into_response(),
            WeatherDataListPresenter::default().into_response(),
        ] {
            assert_eq!(response.status(), StatusCode::INTERNAL_SERVER_ERROR);
            let bytes = to_bytes(response.into_body(), usize::MAX)
                .await
                .expect("body bytes");
            let body: Value = serde_json::from_slice(&bytes).expect("json");
            assert_eq!(body["errors"][0], "internal");
        }
    }
}