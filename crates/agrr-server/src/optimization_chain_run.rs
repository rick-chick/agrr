//! Runnable optimization chain steps (Rails job parity).

use crate::adapters::{NoopLogger, SystemClock};
use crate::state::AppState;
use crate::weather_prediction_anchors::SystemWeatherPredictionAnchors;
use agrr_adapters_agrr::{PlanAllocationAllocateAgrrDaemonGateway, WeatherDaemonGateway};
use agrr_adapters_sqlite::{
    CultivationPlanSqliteGateway, FieldCultivationPlanPredictedWeatherSqliteGateway,
    FieldCultivationSyncPlanReadSqliteGateway, FieldCultivationSyncSqliteGateway,
    PlanAllocationAdjustReadSqliteGateway, WeatherDataFarmSqliteGateway, WeatherDataSqliteGateway,
};
use agrr_domain::cultivation_plan::gateways::CultivationPlanGateway;
use agrr_domain::cultivation_plan::optimization_completion;
use agrr_domain::cultivation_plan::policies::cultivation_plan_optimization_complete_policy;
use agrr_domain::cultivation_plan::dtos::CultivationPlanPhaseName;
use agrr_domain::cultivation_plan::gateways::{
    PlanAllocationAdjustReadGateway, PlanAllocationAllocateGateway,
};
use agrr_domain::cultivation_plan::mappers::{
    AgrrAdjustResultFieldCultivationSyncMapper, PlanAllocationAdjustAgrrPayloadMapper,
};
use agrr_domain::field_cultivation::interactors::FieldCultivationSyncInteractor;
use agrr_domain::field_cultivation::ports::FieldCultivationSyncInputPort;
use agrr_domain::shared::ports::ClockPort;
use agrr_domain::weather_data::dtos::FetchWeatherDataPerformInput;
use agrr_domain::weather_data::interactors::FetchWeatherDataPerformInteractor;
use agrr_domain::weather_data::interactors::WeatherPredictionInteractor;
use agrr_domain::weather_data::ports::{
    FetchWeatherAdvancePhasePort, FetchWeatherDataJobPresenterPort, FetchWeatherPhase,
    RecordFarmWeatherBlockCompletedPort,
};
use agrr_domain::weather_data::OptimizationJobChainWeatherComputation;
use time::{Date, OffsetDateTime};
use tracing::{error, warn};

use crate::cable::CableHub;
use crate::optimization_job_chain::{advance_phase, broadcast_completed, plan_still_optimizing};

#[derive(Clone)]
pub struct ChainContext {
    pub farm_id: i64,
    pub latitude: f64,
    pub longitude: f64,
    pub latest_weather_date: Option<Date>,
    pub all_crops_have_blueprints: bool,
}

pub fn load_chain_context(pool: &agrr_adapters_sqlite::SqlitePool, plan_id: i64) -> Option<ChainContext> {
    pool.with_read(|conn| {
        let row: Result<(i64, f64, f64, Option<String>), _> = conn.query_row(
            "SELECT cp.farm_id, f.latitude, f.longitude, \
             (SELECT MAX(wd.date) FROM weather_data wd \
              WHERE wd.weather_location_id = f.weather_location_id) \
             FROM cultivation_plans cp \
             INNER JOIN farms f ON f.id = cp.farm_id \
             WHERE cp.id = ?1",
            rusqlite::params![plan_id],
            |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?)),
        );
        let Ok((farm_id, latitude, longitude, latest_str)) = row else {
            return Ok(None);
        };
        let latest_weather_date = latest_str
            .as_deref()
            .and_then(|s| Date::parse(s, &time::format_description::well_known::Iso8601::DATE).ok());

        let (crop_count, blueprint_count): (i64, i64) = conn.query_row(
            "SELECT COUNT(DISTINCT cpc.crop_id), \
             COUNT(DISTINCT CASE WHEN ctb.id IS NOT NULL THEN cpc.crop_id END) \
             FROM cultivation_plan_crops cpc \
             LEFT JOIN crop_task_schedule_blueprints ctb ON ctb.crop_id = cpc.crop_id \
             WHERE cpc.cultivation_plan_id = ?1",
            rusqlite::params![plan_id],
            |row| Ok((row.get(0)?, row.get(1)?)),
        )?;
        let all_crops_have_blueprints = crop_count > 0 && crop_count == blueprint_count;

        Ok(Some(ChainContext {
            farm_id,
            latitude,
            longitude,
            latest_weather_date,
            all_crops_have_blueprints,
        }))
    })
    .ok()
    .flatten()
}

struct ChainFetchPresenter;

impl FetchWeatherDataJobPresenterPort for ChainFetchPresenter {
    fn info(&self, message: &str) {
        tracing::info!("{message}");
    }
    fn warn(&self, message: &str) {
        warn!("{message}");
    }
    fn error(&self, message: &str) {
        error!("{message}");
    }
    fn debug(&self, message: &str) {
        tracing::debug!("{message}");
    }
}

struct NoopRecordBlock;

impl RecordFarmWeatherBlockCompletedPort for NoopRecordBlock {
    fn call(
        &self,
        _farm_id: i64,
        _current_time: OffsetDateTime,
    ) -> Option<agrr_domain::weather_data::dtos::FarmWeatherProgressSnapshot> {
        None
    }
}

struct ChainFetchAdvance<'a> {
    state: &'a AppState,
}

impl FetchWeatherAdvancePhasePort for ChainFetchAdvance<'_> {
    fn call(&self, plan_id: i64, phase: FetchWeatherPhase, channel_class: &str) {
        let phase_name = match phase {
            FetchWeatherPhase::FetchingWeather => CultivationPlanPhaseName::PhaseFetchingWeather,
            FetchWeatherPhase::WeatherDataFetched => {
                CultivationPlanPhaseName::PhaseWeatherDataFetched
            }
        };
        advance_phase(self.state, plan_id, channel_class, phase_name, None);
    }
}

pub fn run_fetch_weather_step(
    state: &AppState,
    plan_id: i64,
    channel: &str,
    ctx: &ChainContext,
    start_date: Date,
    end_date: Date,
) -> Result<(), String> {
    let pool = state.sqlite.clone();
    let weather_data = WeatherDataSqliteGateway::new(pool.clone());
    let farm_gateway = WeatherDataFarmSqliteGateway::new(pool);
    let agrr = WeatherDaemonGateway::from_env();
    let presenter = ChainFetchPresenter;
    let advance = ChainFetchAdvance { state };
    let record = NoopRecordBlock;
    let interactor = FetchWeatherDataPerformInteractor::new(
        &weather_data,
        &farm_gateway,
        &advance,
        &record,
        &agrr,
        &presenter,
    );
    let clock = SystemClock;
    let now = clock.now();
    let input = FetchWeatherDataPerformInput {
        latitude: ctx.latitude,
        longitude: ctx.longitude,
        start_date,
        end_date,
        farm_id: Some(ctx.farm_id),
        cultivation_plan_id: Some(plan_id),
        channel_class: Some(channel.to_string()),
        executions: 1,
        current_time: now,
    };
    interactor
        .call(input)
        .map_err(|e| format!("fetch weather perform: {e:?}"))?;

    // Interactor skips API when DB already has enough rows but only advances `weather_data_fetched`
    // on the fetch path (Rails parity). Chain steps must leave `fetching_weather` before predict.
    advance_phase(
        state,
        plan_id,
        channel,
        CultivationPlanPhaseName::PhaseWeatherDataFetched,
        None,
    );
    Ok(())
}

pub fn run_weather_prediction_step(
    state: &AppState,
    plan_id: i64,
    channel: &str,
    end_date: Date,
) -> Result<(), String> {
    advance_phase(
        state,
        plan_id,
        channel,
        CultivationPlanPhaseName::PhasePredictingWeather,
        None,
    );

    let pool = state.sqlite.clone();
    let wl = crate::cultivation_plan_weather_load::load_weather_location(&pool, plan_id)?;
    let weather_data = WeatherDataSqliteGateway::new(pool.clone());
    let plan_predicted = FieldCultivationPlanPredictedWeatherSqliteGateway::new(pool.clone());
    let prediction = agrr_adapters_agrr::PredictionDaemonGateway::from_env();
    let logger = NoopLogger;
    let clock = SystemClock;
    let anchors = SystemWeatherPredictionAnchors;

    let interactor = WeatherPredictionInteractor::new(
        wl,
        &plan_predicted,
        &weather_data,
        &prediction,
        &logger,
        &clock,
        &anchors,
    )
    .map_err(|e| format!("weather prediction init: {e}"))?;

    let plan_weather = crate::cultivation_plan_weather_load::load_plan_weather(&pool, plan_id)?;
    let _predict_days =
        OptimizationJobChainWeatherComputation::predict_days_to_next_year_end(end_date, &clock);
    interactor
        .predict_for_cultivation_plan(&plan_weather, None)
        .map_err(|e| format!("weather prediction: {e}"))?;

    advance_phase(
        state,
        plan_id,
        channel,
        CultivationPlanPhaseName::PhaseWeatherPredictionCompleted,
        None,
    );
    Ok(())
}

pub fn run_optimization_step(state: &AppState, plan_id: i64, channel: &str) -> Result<(), String> {
    advance_phase(
        state,
        plan_id,
        channel,
        CultivationPlanPhaseName::PhaseOptimizing,
        None,
    );

    let pool = state.sqlite.clone();
    let read = PlanAllocationAdjustReadSqliteGateway::new(pool.clone());
    let snapshot = read
        .find_adjust_read_snapshot_by_plan_id(plan_id)
        .map_err(|e| e.to_string())?;

    let fields = PlanAllocationAdjustAgrrPayloadMapper::to_fields_config(&snapshot);
    let crops = PlanAllocationAdjustAgrrPayloadMapper::to_crops_config(&snapshot, None);
    if fields.is_empty() || crops.is_empty() {
        return Err("optimization: empty fields or crops".into());
    }

    let weather = snapshot
        .cultivation_plan_weather_dto
        .predicted_weather_data()
        .cloned()
        .ok_or_else(|| "optimization: predicted_weather_data missing".to_string())?;

    let planning_start = snapshot
        .planning_period_boundaries
        .planning_start_date
        .unwrap_or_else(|| Date::from_calendar_date(2026, time::Month::January, 1).unwrap());
    let planning_end = snapshot
        .planning_period_boundaries
        .planning_end_date
        .unwrap_or_else(|| Date::from_calendar_date(2026, time::Month::December, 31).unwrap());

    let allocate = PlanAllocationAllocateAgrrDaemonGateway::from_env();
    let result = allocate
        .allocate(
            &fields,
            &crops,
            &weather,
            planning_start,
            planning_end,
            None,
            "maximize_profit",
            Some(120),
            false,
        )
        .map_err(|e| e.to_string())?;

    if !agrr_domain::cultivation_plan::policies::cultivation_plan_optimization_complete_policy::allocation_has_field_schedules(&result) {
        return Err("optimization: no field schedules in allocation result".into());
    }

    let sync_input = AgrrAdjustResultFieldCultivationSyncMapper::to_sync_input(&result);
    let sync_gateway = FieldCultivationSyncSqliteGateway::new(pool.clone());
    let sync_read = FieldCultivationSyncPlanReadSqliteGateway::new(pool.clone());
    let logger = NoopLogger;
    let mut sync_interactor =
        FieldCultivationSyncInteractor::new(&sync_gateway, &sync_read, &logger);
    sync_interactor
        .call(plan_id, sync_input)
        .map_err(|e| e.to_string())?;

    let plan_gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let synced = plan_gateway
        .list_by_plan_id(plan_id)
        .map_err(|e| e.to_string())?;
    if synced.is_empty() {
        return Err(
            "optimization: allocation sync produced no field cultivations (check agrr field/crop ids)"
                .into(),
        );
    }

    advance_phase(
        state,
        plan_id,
        channel,
        CultivationPlanPhaseName::PhaseOptimizationCompleted,
        None,
    );
    Ok(())
}

/// Marks the plan completed only when domain policy is satisfied (never raw SQL `completed`).
pub fn run_plan_finalize_step(
    state: &AppState,
    plan_id: i64,
    channel: &str,
    hub: &CableHub,
) -> Result<(), String> {
    let pool = state.sqlite.clone();
    if !plan_still_optimizing(&pool, plan_id) {
        return Ok(());
    }

    let gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let plan = gateway.find_by_id(plan_id).map_err(|e| e.to_string())?;
    let field_cultivations = gateway.list_by_plan_id(plan_id).map_err(|e| e.to_string())?;
    let statuses: Vec<String> = field_cultivations
        .iter()
        .filter_map(|fc| fc.status.clone())
        .collect();
    let plan_status = plan.status.as_deref().unwrap_or("optimizing");

    if field_cultivations.is_empty()
        || !cultivation_plan_optimization_complete_policy::should_mark_plan_completed(
            plan_status,
            &statuses,
        )
    {
        eprintln!(
            "optimization chain finalize rejected plan_id={plan_id}: field_cultivations={} statuses={statuses:?}",
            field_cultivations.len()
        );
        advance_phase(
            state,
            plan_id,
            channel,
            CultivationPlanPhaseName::PhaseFailed,
            Some("optimizing"),
        );
        return Err("optimization chain: cannot finalize without completed field cultivations".into());
    }

    optimization_completion::apply(&gateway, plan_id).map_err(|e| e.to_string())?;
    advance_phase(
        state,
        plan_id,
        channel,
        CultivationPlanPhaseName::PhaseCompleted,
        None,
    );
    broadcast_completed(hub, plan_id, &pool);
    eprintln!(
        "optimization chain finalized plan_id={plan_id} field_cultivations={}",
        field_cultivations.len()
    );
    Ok(())
}

