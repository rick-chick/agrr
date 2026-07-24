//! In-process farm weather fetch jobs (`FetchWeatherDataJob` parity).

use std::sync::Arc;
use std::time::Duration;

use crate::adapters::SystemClock;
use crate::cable::CableFarmRefreshBroadcast;
use crate::jobs::JobStep;
use crate::state::AppState;
use agrr_adapters_agrr::WeatherDaemonGateway;
use agrr_adapters_sqlite::{
    FarmSqliteGateway, PendingFarmWeatherBackfillSqliteGateway, WeatherDataFarmSqliteGateway,
    WeatherDataGatewayBundle,
};
use agrr_domain::farm::interactors::PendingFarmWeatherBackfillInteractor;
use agrr_domain::farm::calculators::FarmWeatherProgressCalculator;
use agrr_domain::farm::dtos::{
    MarkFarmWeatherDataFailedInput, RecordFarmWeatherBlockCompletedInput,
    StartFarmWeatherDataFetchInput,
};
use agrr_domain::farm::interactors::{
    MarkFarmWeatherDataFailedInteractor, RecordFarmWeatherBlockCompletedInteractor,
    StartFarmWeatherDataFetchInteractor,
};
use agrr_domain::weather_data::interactors::FetchWeatherDataPerformError;
use agrr_domain::shared::dtos::WeatherFetchDateBlock;
use agrr_domain::shared::ports::FetchWeatherDataEnqueuePort;
use agrr_domain::weather_data::dtos::FetchWeatherDataPerformInput;
use agrr_domain::weather_data::gateways::{
    StartFarmWeatherDataFetchPort, StartedFarmWeatherFetchSnapshot,
};
use agrr_domain::weather_data::interactors::FetchWeatherDataPerformInteractor;
use agrr_domain::shared::ports::ClockPort;
use agrr_domain::weather_data::ports::{
    FetchWeatherAdvancePhasePort, FetchWeatherDataJobPresenterPort, FetchWeatherPhase,
    RecordFarmWeatherBlockCompletedPort,
};
use time::{Date, OffsetDateTime};

/// Enqueues sequential in-process fetch steps (Rails `FetchWeatherDataActiveJobAdapter`).
pub struct FetchWeatherDataJobEnqueue {
    state: AppState,
}

impl FetchWeatherDataJobEnqueue {
    pub fn new(state: AppState) -> Self {
        Self { state }
    }
}

impl FetchWeatherDataEnqueuePort for FetchWeatherDataJobEnqueue {
    fn enqueue_farm_weather_fetch(
        &self,
        farm_id: i64,
        latitude: f64,
        longitude: f64,
        blocks: &[WeatherFetchDateBlock],
    ) {
        let mut steps = Vec::new();
        for (index, block) in blocks.iter().enumerate() {
            let state = self.state.clone();
            let start_date = block.start_date;
            let end_date = block.end_date;
            let delay_secs = index as u64;
            steps.push(JobStep {
                name: "fetch_farm_weather_data",
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

struct FarmFetchPresenter;

impl FetchWeatherDataJobPresenterPort for FarmFetchPresenter {
    fn info(&self, message: &str) {
        tracing::info!("{message}");
    }
    fn warn(&self, message: &str) {
        tracing::warn!("{message}");
    }
    fn error(&self, message: &str) {
        tracing::error!("{message}");
    }
    fn debug(&self, message: &str) {
        tracing::debug!("{message}");
    }
}

struct NoopAdvancePhase;

impl FetchWeatherAdvancePhasePort for NoopAdvancePhase {
    fn call(&self, _plan_id: i64, _phase: FetchWeatherPhase, _channel_class: &str) {}
}

struct RecordBlockAdapter<'a> {
    farm_gateway: &'a FarmSqliteGateway,
    broadcast: CableFarmRefreshBroadcast,
}

impl<'a> RecordBlockAdapter<'a> {
    fn new(farm_gateway: &'a FarmSqliteGateway, broadcast: CableFarmRefreshBroadcast) -> Self {
        Self {
            farm_gateway,
            broadcast,
        }
    }
}

impl RecordFarmWeatherBlockCompletedPort for RecordBlockAdapter<'_> {
    fn call(
        &self,
        farm_id: i64,
        current_time: OffsetDateTime,
    ) -> Option<agrr_domain::weather_data::dtos::FarmWeatherProgressSnapshot> {
        let interactor: RecordFarmWeatherBlockCompletedInteractor<'_, FarmSqliteGateway, CableFarmRefreshBroadcast> =
            RecordFarmWeatherBlockCompletedInteractor::new(self.farm_gateway, Some(&self.broadcast));
        let ts = current_time.unix_timestamp() as f64;
        let updated = interactor
            .call(RecordFarmWeatherBlockCompletedInput {
                farm_id,
                current_time: ts,
            })
            .ok()
            .flatten()?;
        Some(agrr_domain::weather_data::dtos::FarmWeatherProgressSnapshot {
            weather_data_progress: updated.weather_data_progress(),
            weather_data_fetched_years: updated.weather_data_fetched_years.unwrap_or(0),
            weather_data_total_years: updated.weather_data_total_years.unwrap_or(0),
        })
    }
}

pub async fn run_farm_weather_fetch_block(
    state: &AppState,
    farm_id: i64,
    latitude: f64,
    longitude: f64,
    start_date: Date,
    end_date: Date,
) {
    let pool = state.sqlite.clone();
    let weather_data = match WeatherDataGatewayBundle::resolve(pool.clone()) {
        Ok(bundle) => bundle,
        Err(e) => {
            tracing::warn!(?e, "weather data gateway resolve failed");
            return;
        }
    };
    let farm_weather = WeatherDataFarmSqliteGateway::new(pool.clone());
    let farm_gateway = FarmSqliteGateway::new(pool);
    let agrr = WeatherDaemonGateway::from_env();
    let presenter = FarmFetchPresenter;
    let advance = NoopAdvancePhase;
    let record = RecordBlockAdapter::new(
        &farm_gateway,
        CableFarmRefreshBroadcast::new(state.cable_hub.clone()),
    );
    let interactor = FetchWeatherDataPerformInteractor::new(
        &weather_data,
        &farm_weather,
        &advance,
        &record,
        &agrr,
        &presenter,
    );
    let clock = SystemClock;
    let now = clock.now();
    let input = FetchWeatherDataPerformInput {
        latitude,
        longitude,
        start_date,
        end_date,
        farm_id: Some(farm_id),
        cultivation_plan_id: None,
        channel_class: None,
        executions: 1,
        current_time: now,
    };
    if let Err(e) = interactor.call(input) {
        tracing::warn!(farm_id, ?e, "farm weather fetch block failed");
        mark_farm_weather_fetch_failed(&farm_gateway, farm_id, &e);
    }
}

fn mark_farm_weather_fetch_failed(
    farm_gateway: &FarmSqliteGateway,
    farm_id: i64,
    err: &FetchWeatherDataPerformError,
) {
    let error_message = format!("fetch weather data failed: {err}");
    if let Err(mark_err) = MarkFarmWeatherDataFailedInteractor::new(farm_gateway).call(
        MarkFarmWeatherDataFailedInput {
            farm_id,
            error_message,
        },
    ) {
        tracing::warn!(farm_id, ?mark_err, "failed to mark farm weather data failed");
    }
}

/// `StartFarmWeatherDataFetchPort` for internal weather fetch start interactor.
pub struct StartFarmWeatherFetchAdapter {
    farm_gateway: FarmSqliteGateway,
    enqueue: FetchWeatherDataJobEnqueue,
}

impl StartFarmWeatherFetchAdapter {
    pub fn new(state: AppState) -> Self {
        let pool = state.sqlite.clone();
        Self {
            farm_gateway: FarmSqliteGateway::new(pool),
            enqueue: FetchWeatherDataJobEnqueue::new(state),
        }
    }
}

impl StartFarmWeatherDataFetchPort for StartFarmWeatherFetchAdapter {
    fn call(&self, farm_id: i64, as_of: Date) -> Option<StartedFarmWeatherFetchSnapshot> {
        let interactor =
            StartFarmWeatherDataFetchInteractor::new(&self.farm_gateway, &self.enqueue);
        let input = StartFarmWeatherDataFetchInput { farm_id, as_of };
        match interactor.call(input) {
            Ok(Some(_farm)) => {
                let attrs = FarmWeatherProgressCalculator::start_fetch_attrs(as_of.year());
                let total = attrs
                    .get("weather_data_total_years")
                    .and_then(|v| match v {
                        agrr_domain::shared::attr::AttrValue::Int(n) => Some(*n as i32),
                        _ => None,
                    })
                    .unwrap_or(0);
                Some(StartedFarmWeatherFetchSnapshot {
                    weather_data_status: "fetching".to_string(),
                    weather_data_total_years: total,
                })
            }
            Ok(None) => None,
            Err(e) => {
                tracing::warn!(farm_id, error = %e, "start farm weather fetch failed");
                None
            }
        }
    }
}

/// Backfill initial weather fetch for user farms left at `pending` (pre-#464).
pub fn run_pending_farm_weather_backfill(state: &AppState) {
    let pool = state.sqlite.clone();
    let list_gateway = PendingFarmWeatherBackfillSqliteGateway::new(pool);
    let start_fetch = StartFarmWeatherFetchAdapter::new(state.clone());
    let clock = SystemClock;
    let interactor =
        PendingFarmWeatherBackfillInteractor::new(&list_gateway, &start_fetch, &clock);
    match interactor.call() {
        Ok(started) => {
            if started > 0 {
                tracing::info!(started, "pending farm weather backfill enqueued");
            }
        }
        Err(message) => {
            tracing::warn!(error = %message, "pending farm weather backfill failed");
        }
    }
}
