//! Scheduler weather update (`POST /api/v1/internal/jobs/trigger_weather_update`).

use std::sync::{Arc, Mutex};

use crate::adapters::SystemClock;
use crate::farm_weather_fetch::run_farm_weather_fetch_block;
use crate::jobs::JobStep;
use crate::state::AppState;
use agrr_adapters_sqlite::SchedulerWeatherFarmListSqliteGateway;
use crate::weather_data_gateway_factory::WeatherDataGatewayBundle;
use agrr_domain::internal_jobs::gateways::{
    EnqueueWeatherUpdateJobsResult, WeatherUpdateJobsEnqueueGateway,
};
use agrr_domain::internal_jobs::interactors::SchedulerWeatherBatchEnqueueInteractor;
use agrr_domain::internal_jobs::ports::SchedulerWeatherFetchSchedulePort;
use agrr_domain::internal_jobs::dtos::SchedulerWeatherUpdateTriggerFailure;
use agrr_domain::internal_jobs::interactors::SchedulerWeatherUpdateJobsTriggerInteractor;
use agrr_domain::internal_jobs::ports::SchedulerWeatherUpdateTriggerOutputPort;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde_json::Value;
use time::{format_description::well_known::Rfc3339, Date, OffsetDateTime};
use tokio::time::Duration;

struct PendingSchedulerFetch {
    farm_id: i64,
    latitude: f64,
    longitude: f64,
    start_date: Date,
    end_date: Date,
    delay_secs: u64,
}

/// Collects fetch steps and flushes as one in-process chain (Rails staggered `FetchWeatherDataJob`).
pub struct SchedulerWeatherFetchScheduleAdapter {
    state: AppState,
    pending: Mutex<Vec<PendingSchedulerFetch>>,
}

impl SchedulerWeatherFetchScheduleAdapter {
    pub fn new(state: AppState) -> Self {
        Self {
            state,
            pending: Mutex::new(Vec::new()),
        }
    }
}

impl SchedulerWeatherFetchSchedulePort for SchedulerWeatherFetchScheduleAdapter {
    fn schedule_fetch(
        &self,
        farm_id: i64,
        latitude: f64,
        longitude: f64,
        start_date: Date,
        end_date: Date,
        delay_secs: u64,
    ) {
        self.pending.lock().expect("lock").push(PendingSchedulerFetch {
            farm_id,
            latitude,
            longitude,
            start_date,
            end_date,
            delay_secs,
        });
    }

    fn flush(&self) {
        let pending = std::mem::take(&mut *self.pending.lock().expect("lock"));
        if pending.is_empty() {
            return;
        }
        let mut steps = Vec::with_capacity(pending.len());
        for fetch in pending {
            let state = self.state.clone();
            let delay_secs = fetch.delay_secs;
            let farm_id = fetch.farm_id;
            let latitude = fetch.latitude;
            let longitude = fetch.longitude;
            let start_date = fetch.start_date;
            let end_date = fetch.end_date;
            steps.push(JobStep {
                name: "scheduler_fetch_weather_data",
                run: Arc::new(move || {
                    let state = state.clone();
                    Box::pin(async move {
                        if delay_secs > 0 {
                            tokio::time::sleep(Duration::from_secs(delay_secs)).await;
                        }
                        run_farm_weather_fetch_block(
                            &state,
                            farm_id,
                            latitude,
                            longitude,
                            start_date,
                            end_date,
                        )
                        .await;
                        true
                    })
                }),
            });
        }
        self.state.weather_fetch_job_dispatcher.enqueue_chain(steps);
    }
}

/// Ruby: `Adapters::InternalJobs::Gateways::WeatherUpdateJobsEnqueueActiveJobGateway`
pub struct WeatherUpdateJobsEnqueueInProcessGateway {
    state: AppState,
}

impl WeatherUpdateJobsEnqueueInProcessGateway {
    pub fn new(state: AppState) -> Self {
        Self { state }
    }
}

impl WeatherUpdateJobsEnqueueGateway for WeatherUpdateJobsEnqueueInProcessGateway {
    fn enqueue_weather_update_jobs(&self) -> EnqueueWeatherUpdateJobsResult {
        let pool = self.state.sqlite.clone();
        let weather_bundle = match WeatherDataGatewayBundle::resolve(pool.clone()) {
            Ok(bundle) => bundle,
            Err(message) => {
                return EnqueueWeatherUpdateJobsResult::failure(message.to_string());
            }
        };
        let list_gateway =
            SchedulerWeatherFarmListSqliteGateway::new(pool, &weather_bundle);
        let schedule = SchedulerWeatherFetchScheduleAdapter::new(self.state.clone());
        let clock = SystemClock;
        let interactor =
            SchedulerWeatherBatchEnqueueInteractor::new(&list_gateway, &schedule, &clock);
        match interactor.call() {
            Ok(()) => EnqueueWeatherUpdateJobsResult::success(),
            Err(message) => EnqueueWeatherUpdateJobsResult::failure(message),
        }
    }
}

pub struct SchedulerWeatherUpdateTriggerApiPresenter {
    pub response: Option<Response>,
}

impl SchedulerWeatherUpdateTriggerApiPresenter {
    pub fn new() -> Self {
        Self { response: None }
    }

    fn success_json() -> Value {
        let timestamp = OffsetDateTime::now_utc()
            .format(&Rfc3339)
            .unwrap_or_else(|_| OffsetDateTime::now_utc().unix_timestamp().to_string());
        serde_json::json!({
            "success": true,
            "message": "Weather update jobs enqueued",
            "timestamp": timestamp,
        })
    }
}

impl Default for SchedulerWeatherUpdateTriggerApiPresenter {
    fn default() -> Self {
        Self::new()
    }
}

impl SchedulerWeatherUpdateTriggerOutputPort for SchedulerWeatherUpdateTriggerApiPresenter {
    fn on_success(&mut self) {
        self.response = Some(
            (StatusCode::OK, Json(Self::success_json())).into_response(),
        );
    }

    fn on_failure(&mut self, failure_dto: SchedulerWeatherUpdateTriggerFailure) {
        self.response = Some(
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({
                    "success": false,
                    "error": failure_dto.message,
                })),
            )
                .into_response(),
        );
    }
}

pub fn trigger_scheduler_weather_update(state: &AppState) -> Response {
    let gateway = WeatherUpdateJobsEnqueueInProcessGateway::new(state.clone());
    let mut presenter = SchedulerWeatherUpdateTriggerApiPresenter::new();
    let mut interactor =
        SchedulerWeatherUpdateJobsTriggerInteractor::new(&mut presenter, &gateway);
    interactor.call();
    presenter
        .response
        .unwrap_or_else(|| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({
                    "success": false,
                    "error": "No response from presenter",
                })),
            )
                .into_response()
        })
}
