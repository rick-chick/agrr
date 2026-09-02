//! Public entry schedule (`/api/v1/public_plans/entry_schedule/crops*`).

use crate::adapters::{NoopLogger, SystemClock};
use crate::adjust_weather_prediction::resolve_weather_for_entry_schedule;
use crate::cultivation_plan_weather_load::load_weather_location_by_id;
use crate::state::AppState;
use axum::http::HeaderMap;
use agrr_adapters_agrr::{
    use_agrr_daemon_enabled, EntryScheduleOptimizationAgrrDaemonGateway,
};
use agrr_adapters_sqlite::{CropSqliteGateway, FarmSqliteGateway};
use agrr_domain::crop::dtos::CropFindReferenceForEntryScheduleInput;
use agrr_domain::crop::entities::CropEntity;
use agrr_domain::crop::gateways::CropGateway;
use agrr_domain::crop::interactors::crop_find_reference_for_entry_schedule_interactor::{
    CropFindReferenceForEntryScheduleInteractor, CropFindReferenceForEntryScheduleOutputPort,
};
use agrr_domain::crop::policies::crop_reference_record_policy;
use agrr_domain::cultivation_plan::gateways::EntryScheduleCropGateway as CultivationEntryScheduleCropGateway;
use agrr_domain::public_plan::ports::EntryScheduleCropGateway;
use agrr_domain::cultivation_plan::interactors::entry_schedule::CropStageSnapshot;
use agrr_domain::cultivation_plan::interactors::{
    EntryScheduleOptimizeCrop, EntryScheduleOptimizeInteractor,
};
use agrr_domain::public_plan::interactors::{
    EntryScheduleOptimizationRunnerPort, EntryScheduleShowCrop, EntryScheduleShowFarm,
    EntryScheduleWeatherLoaderPort,
};
use agrr_domain::farm::entities::FarmEntity;
use agrr_domain::farm::gateways::FarmGateway;
use agrr_domain::public_plan::dtos::{EntryScheduleFailure, EntryScheduleShowOutput};
use agrr_domain::public_plan::exceptions::{
    PredictionPayloadMissingError, WeatherLocationMissingError, WeatherPredictionFailedError,
};
use agrr_domain::public_plan::interactors::EntryScheduleShowInteractor;
use agrr_domain::public_plan::mappers::entry_schedule_crop_mapper::{
    self, CropStageRow, EntryScheduleWindowResult,
};
use agrr_domain::public_plan::ports::EntryScheduleShowOutputPort;
use agrr_domain::shared::dtos::Error;
use agrr_domain::shared::ports::{
    ClockPort, CropAgrrRequirementBuilderPort, CropAgrrRequirementSource,
};
use agrr_domain::weather_data::WeatherPredictionError;
use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::BTreeMap;
use time::Date;

#[derive(Deserialize)]
pub struct EntryScheduleCropsQuery {
    farm_id: i64,
    prediction_end_date: Option<String>,
    limit: Option<i32>,
    cursor: Option<String>,
}

#[derive(Deserialize)]
pub struct EntryScheduleShowQuery {
    farm_id: i64,
    prediction_end_date: Option<String>,
}

struct FarmWrap(FarmEntity);

impl entry_schedule_crop_mapper::EntryScheduleFarmLike for FarmWrap {
    fn weather_location_id(&self) -> Option<i64> {
        self.0.weather_location_id
    }
}

impl EntryScheduleShowFarm for FarmWrap {
    fn id(&self) -> i64 {
        self.0.id
    }
    fn name(&self) -> &str {
        &self.0.name
    }
    fn latitude(&self) -> f64 {
        self.0.latitude.unwrap_or(0.0)
    }
    fn longitude(&self) -> f64 {
        self.0.longitude.unwrap_or(0.0)
    }
    fn region(&self) -> &str {
        self.0.region.as_deref().unwrap_or("jp")
    }
}

struct CropWrap(CropEntity);

impl entry_schedule_crop_mapper::EntryScheduleCropLike for CropWrap {
    fn id(&self) -> i64 {
        self.0.id
    }
    fn name(&self) -> &str {
        &self.0.name
    }
}

impl EntryScheduleShowCrop for CropWrap {}

impl CropAgrrRequirementSource for CropWrap {}

impl EntryScheduleOptimizeCrop for CropWrap {
    fn crop_id(&self) -> i64 {
        self.0.id
    }
    fn crop_name(&self) -> &str {
        &self.0.name
    }
    fn crop_variety(&self) -> Option<&str> {
        self.0.variety.as_deref()
    }
}

struct AgrrCropBuilder {
    pool: agrr_adapters_sqlite::SqlitePool,
    crop_id: i64,
}

impl CropAgrrRequirementBuilderPort for AgrrCropBuilder {
    fn build_from(&self, _source: &dyn CropAgrrRequirementSource) -> Value {
        agrr_adapters_sqlite::crop::agrr_requirement::build_crop_agrr_requirement(
            &self.pool,
            self.crop_id,
        )
        .ok()
        .flatten()
        .unwrap_or(json!({}))
    }
}

struct SqliteShowCropGateway {
    crop_gateway: CropSqliteGateway,
}

impl EntryScheduleCropGateway for SqliteShowCropGateway {
    fn list_by_crop_id(&self, crop_id: i64) -> Vec<CropStageRow> {
        stage_rows(&self.crop_gateway, crop_id)
    }
}

struct SqliteOptimizeCropGateway {
    pool: agrr_adapters_sqlite::SqlitePool,
    crop_gateway: CropSqliteGateway,
}

impl CultivationEntryScheduleCropGateway for SqliteOptimizeCropGateway {
    fn entry_schedule_ordered_stage_rows(
        &self,
        crop_id: i64,
    ) -> Result<Vec<CropStageSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
        let stages = self.crop_gateway.list_by_crop_id(crop_id)?;
        let mut rows = Vec::with_capacity(stages.len());
        for s in stages {
            let temperature_requirement = self
                .pool
                .with_read(|conn| load_entry_schedule_temperature(conn, s.id))
                .ok()
                .flatten();
            rows.push(CropStageSnapshot {
                id: s.id,
                name: s.name,
                order: s.order,
                temperature_requirement,
            });
        }
        Ok(rows)
    }
}

fn load_entry_schedule_temperature(
    conn: &rusqlite::Connection,
    crop_stage_id: i64,
) -> rusqlite::Result<Option<agrr_domain::cultivation_plan::interactors::entry_schedule::TemperatureRequirementSnapshot>> {
    use agrr_domain::cultivation_plan::interactors::entry_schedule::TemperatureRequirementSnapshot;
    use rusqlite::OptionalExtension;
    conn.query_row(
        "SELECT frost_threshold, optimal_min, optimal_max, base_temperature \
         FROM temperature_requirements WHERE crop_stage_id = ?1",
        rusqlite::params![crop_stage_id],
        |row| {
            Ok(TemperatureRequirementSnapshot {
                frost_threshold: row.get(0)?,
                optimal_min: row.get(1)?,
                optimal_max: row.get(2)?,
                base_temperature: row.get(3)?,
            })
        },
    )
    .optional()
}

struct EntryScheduleWeatherLoader<'a> {
    state: &'a AppState,
}

fn map_weather_prediction_error(
    err: WeatherPredictionError,
) -> Box<dyn std::error::Error + Send + Sync> {
    match err {
        WeatherPredictionError::WeatherLocationRequired => {
            Box::new(WeatherLocationMissingError)
        }
        WeatherPredictionError::InsufficientPredictionData(msg)
        | WeatherPredictionError::WeatherDataNotFound(msg)
        | WeatherPredictionError::WeatherDataStorageFailed(msg) => {
            if msg.contains("no data rows") {
                Box::new(PredictionPayloadMissingError)
            } else {
                Box::new(WeatherPredictionFailedError(msg))
            }
        }
        other => Box::new(WeatherPredictionFailedError(other.to_string())),
    }
}

impl EntryScheduleWeatherLoaderPort for EntryScheduleWeatherLoader<'_> {
    fn load_prediction_payload(
        &self,
        farm: &dyn EntryScheduleShowFarm,
        prediction_end_date_raw: Option<&str>,
        reference_date: Date,
    ) -> Result<BTreeMap<String, Value>, Box<dyn std::error::Error + Send + Sync>> {
        let weather_location_id = farm
            .weather_location_id()
            .ok_or_else(|| Box::new(WeatherLocationMissingError) as Box<dyn std::error::Error + Send + Sync>)?;
        let weather_location = load_weather_location_by_id(&self.state.sqlite, weather_location_id)
            .map_err(|_| Box::new(WeatherLocationMissingError) as Box<dyn std::error::Error + Send + Sync>)?;

        let weather_value = resolve_weather_for_entry_schedule(
            self.state,
            &weather_location,
            reference_date,
            prediction_end_date_raw,
        )
        .map_err(map_weather_prediction_error)?;

        let map = match weather_value {
            Value::Object(obj) => obj.into_iter().collect::<BTreeMap<String, Value>>(),
            _ => BTreeMap::new(),
        };
        let weather_data_len = map
            .get("data")
            .and_then(|v| v.as_array())
            .map(|a| a.len())
            .unwrap_or(0);
        if weather_data_len == 0 {
            return Err(Box::new(PredictionPayloadMissingError));
        }
        Ok(map)
    }
}

struct OptimizeRunner {
    pool: agrr_adapters_sqlite::SqlitePool,
    optimization: EntryScheduleOptimizationAgrrDaemonGateway,
    agrr_enabled: bool,
}

impl EntryScheduleOptimizationRunnerPort for OptimizeRunner {
    fn call(
        &self,
        crop: &dyn EntryScheduleShowCrop,
        weather_payload: &BTreeMap<String, Value>,
        _farm: &dyn EntryScheduleShowFarm,
    ) -> EntryScheduleWindowResult {
        let entity = CropEntity::new(crop.id(), crop.name(), None, true).unwrap();
        let wrap = CropWrap(entity);
        let crop_gw = SqliteOptimizeCropGateway {
            pool: self.pool.clone(),
            crop_gateway: CropSqliteGateway::new(self.pool.clone()),
        };
        let builder = AgrrCropBuilder {
            pool: self.pool.clone(),
            crop_id: crop.id(),
        };
        let interactor = EntryScheduleOptimizeInteractor::new(
            &wrap,
            Value::Object(weather_payload.clone().into_iter().collect()),
            &crop_gw,
            &builder,
            &self.optimization,
            &SystemClock,
            Some(&NoopLogger),
            self.agrr_enabled,
        );
        let r = interactor.call();
        EntryScheduleWindowResult {
            eligible: r.eligible,
            sowing_windows: r
                .sowing_windows
                .into_iter()
                .map(|w| entry_schedule_crop_mapper::DateWindow {
                    start_date: w.start_date,
                    end_date: w.end_date,
                })
                .collect(),
            transplant_windows: r
                .transplant_windows
                .into_iter()
                .map(|w| entry_schedule_crop_mapper::DateWindow {
                    start_date: w.start_date,
                    end_date: w.end_date,
                })
                .collect(),
            reason_parts: r.reason_parts,
            sowing_stage_id: r.sowing_stage_id,
            transplant_stage_id: r.transplant_stage_id,
            weather_end_date: r.weather_end_date,
        }
    }
}

struct ShowOut {
    status: StatusCode,
    body: Value,
}

struct ShowPresenter {
    out: Option<ShowOut>,
}

impl EntryScheduleShowOutputPort for ShowPresenter {
    fn on_success(&mut self, dto: EntryScheduleShowOutput) {
        let root = dto.to_h();
        self.out = Some(ShowOut {
            status: StatusCode::OK,
            body: json!({
                "farm": root.get("farm"),
                "prediction": root.get("prediction"),
                "crop": root.get("crop"),
            }),
        });
    }

    fn on_failure(&mut self, failure: EntryScheduleFailure) {
        let status = match failure.kind {
            agrr_domain::public_plan::dtos::EntryScheduleFailureKind::WeatherLocationRequired => {
                StatusCode::UNPROCESSABLE_ENTITY
            }
            agrr_domain::public_plan::dtos::EntryScheduleFailureKind::PredictionPayloadMissing
            | agrr_domain::public_plan::dtos::EntryScheduleFailureKind::WeatherPredictionFailed => {
                StatusCode::SERVICE_UNAVAILABLE
            }
            agrr_domain::public_plan::dtos::EntryScheduleFailureKind::RecordNotFound => {
                StatusCode::NOT_FOUND
            }
            _ => StatusCode::INTERNAL_SERVER_ERROR,
        };
        self.out = Some(ShowOut {
            status,
            body: json!({
                "error": failure.detail_message,
                "error_key": format!("{:?}", failure.kind),
            }),
        });
    }
}

struct CropResolveOut {
    crop: Option<CropEntity>,
    failed: bool,
}

impl CropFindReferenceForEntryScheduleOutputPort for CropResolveOut {
    fn on_success(&mut self, entity: CropEntity) {
        self.crop = Some(entity);
    }
    fn on_failure(&mut self, _error: Error) {
        self.failed = true;
    }
}

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/public_plans/entry_schedule/crops",
            get(entry_schedule_crops),
        )
        .route(
            "/api/v1/public_plans/entry_schedule/crops/{id}",
            get(entry_schedule_crop_show),
        )
}

async fn load_farm(state: &AppState, farm_id: i64) -> Result<FarmEntity, (StatusCode, Json<Value>)> {
    FarmSqliteGateway::new(state.sqlite.clone())
        .find_by_id(farm_id)
        .map_err(|_| {
            (
                StatusCode::NOT_FOUND,
                Json(json!({"error": "farm not found"})),
            )
        })
}

fn stage_rows(crop_gateway: &CropSqliteGateway, crop_id: i64) -> Vec<CropStageRow> {
    crop_gateway
        .list_by_crop_id(crop_id)
        .unwrap_or_default()
        .into_iter()
        .map(|s| CropStageRow {
            id: s.id,
            name: s.name,
            order: s.order,
        })
        .collect()
}

async fn entry_schedule_crop_show(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(crop_id): Path<i64>,
    Query(query): Query<EntryScheduleShowQuery>,
) -> impl IntoResponse {
    let translator = state.locale_translator(&headers);
    let farm = match load_farm(&state, query.farm_id).await {
        Ok(f) => f,
        Err(e) => return e.into_response(),
    };
    let pool = state.sqlite.clone();
    let crop_gateway = CropSqliteGateway::new(pool.clone());
    let region = farm.region.clone().unwrap_or_else(|| "jp".into());
    let mut resolve = CropResolveOut {
        crop: None,
        failed: false,
    };
    CropFindReferenceForEntryScheduleInteractor::new(&mut resolve, &crop_gateway, &NoopLogger)
        .call(CropFindReferenceForEntryScheduleInput {
            region: Some(region.clone()),
            crop_id,
        })
        .ok();
    let Some(crop) = resolve.crop else {
        return (
            StatusCode::NOT_FOUND,
            Json(json!({"error": "crop not found"})),
        )
            .into_response();
    };
    let agrr_enabled = use_agrr_daemon_enabled();
    let runner = OptimizeRunner {
        pool: pool.clone(),
        optimization: EntryScheduleOptimizationAgrrDaemonGateway::from_env(),
        agrr_enabled,
    };
    let crop_gw = SqliteShowCropGateway {
        crop_gateway: CropSqliteGateway::new(state.sqlite.clone()),
    };
    let mut presenter = ShowPresenter { out: None };
    let weather_loader = EntryScheduleWeatherLoader { state: &state };
    let mut interactor = EntryScheduleShowInteractor::new(
        &mut presenter,
        &crop_gw,
        &weather_loader,
        &runner,
        &translator,
        &SystemClock,
    );
    interactor.call(
        &FarmWrap(farm),
        &CropWrap(crop),
        ClockPort::today(&SystemClock),
        query.prediction_end_date.as_deref(),
    );
    match presenter.out {
        Some(ShowOut { status, body }) => (status, Json(body)).into_response(),
        None => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": "no response"})),
        )
            .into_response(),
    }
}

async fn entry_schedule_crops(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<EntryScheduleCropsQuery>,
) -> impl IntoResponse {
    let farm = match load_farm(&state, query.farm_id).await {
        Ok(f) => f,
        Err(e) => return e.into_response(),
    };
    let pool = state.sqlite.clone();
    let crop_gateway = CropSqliteGateway::new(pool.clone());
    let region = farm.region.clone().unwrap_or_else(|| "jp".into());
    let reference_crops = crop_gateway
        .list_by_is_reference(true, Some(&region))
        .unwrap_or_default();
    let agrr_enabled = use_agrr_daemon_enabled();
    let runner = OptimizeRunner {
        pool: pool.clone(),
        optimization: EntryScheduleOptimizationAgrrDaemonGateway::from_env(),
        agrr_enabled,
    };
    let weather_loader = EntryScheduleWeatherLoader { state: &state };
    let weather = match weather_loader.load_prediction_payload(
        &FarmWrap(farm.clone()),
        query.prediction_end_date.as_deref(),
        SystemClock.today(),
    ) {
        Ok(w) => w,
        Err(err) => {
            if err.downcast_ref::<WeatherLocationMissingError>().is_some() {
                return (
                    StatusCode::UNPROCESSABLE_ENTITY,
                    Json(json!({"error": "weather_location_required"})),
                )
                    .into_response();
            }
            if err.downcast_ref::<PredictionPayloadMissingError>().is_some() {
                return (
                    StatusCode::SERVICE_UNAVAILABLE,
                    Json(json!({"error": "prediction_payload_missing"})),
                )
                    .into_response();
            }
            let message = err
                .downcast_ref::<WeatherPredictionFailedError>()
                .map(|e| e.0.clone())
                .unwrap_or_else(|| err.to_string());
            return (
                StatusCode::SERVICE_UNAVAILABLE,
                Json(json!({"error": message})),
            )
                .into_response();
        }
    };
    let translator = state.locale_translator(&headers);
    let mut items = Vec::new();
    for crop in reference_crops {
        if !crop_reference_record_policy::visible_for_entry_schedule(
            &crop,
            Some(region.as_str()),
            crop.region.as_deref(),
        ) {
            continue;
        }
        let wrap = CropWrap(crop.clone());
        let result = runner.call(&wrap, &weather, &FarmWrap(farm.clone()));
        let detail = entry_schedule_crop_mapper::crop_detail(
            &wrap,
            &result,
            &translator,
            &stage_rows(&crop_gateway, crop.id),
            &SystemClock,
        );
        let mut list_item = detail.clone();
        list_item.remove("sowing_windows");
        list_item.remove("transplant_windows");
        list_item.remove("reason_parts");
        list_item.remove("crop_stages");
        list_item.remove("phase_segments");
        list_item.remove("rough_timeline");
        items.push(Value::Object(list_item.into_iter().collect()));
    }
    let limit = query.limit.unwrap_or(20).clamp(1, 50) as usize;
    let offset = query
        .cursor
        .and_then(|c| c.parse::<usize>().ok())
        .unwrap_or(0);
    let total = items.len();
    let page: Vec<_> = items.into_iter().skip(offset).take(limit).collect();
    let next_offset = offset + page.len();
    let prediction_meta = entry_schedule_crop_mapper::prediction_meta(
        &FarmWrap(farm.clone()),
        &weather,
        SystemClock.today().year(),
    );
    (
        StatusCode::OK,
        Json(json!({
            "farm": {
                "id": farm.id,
                "name": farm.name,
                "latitude": farm.latitude,
                "longitude": farm.longitude,
                "region": farm.region,
            },
            "prediction": prediction_meta,
            "meta": {
                "total_count": total,
                "limit": limit,
                "next_cursor": if next_offset < total { Some(next_offset.to_string()) } else { None::<String> },
                "has_more": next_offset < total,
            },
            "crops": page,
        })),
    )
        .into_response()
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::public_plan::exceptions::{
        PredictionPayloadMissingError, WeatherLocationMissingError, WeatherPredictionFailedError,
    };
    use agrr_domain::weather_data::WeatherPredictionError;

    #[test]
    fn map_weather_prediction_error_maps_location_required() {
        let err = map_weather_prediction_error(WeatherPredictionError::WeatherLocationRequired);
        assert!(err.downcast_ref::<WeatherLocationMissingError>().is_some());
    }

    #[test]
    fn map_weather_prediction_error_maps_no_data_rows_to_payload_missing() {
        let err = map_weather_prediction_error(WeatherPredictionError::InsufficientPredictionData(
            "weather payload has no data rows".into(),
        ));
        assert!(err.downcast_ref::<PredictionPayloadMissingError>().is_some());
    }

    #[test]
    fn map_weather_prediction_error_maps_weather_data_not_found_no_data_rows() {
        let err = map_weather_prediction_error(WeatherPredictionError::WeatherDataNotFound(
            "no data rows in cache".into(),
        ));
        assert!(err.downcast_ref::<PredictionPayloadMissingError>().is_some());
    }

    #[test]
    fn map_weather_prediction_error_maps_other_insufficient_data_to_failed() {
        let err = map_weather_prediction_error(WeatherPredictionError::InsufficientPredictionData(
            "daemon timeout".into(),
        ));
        let failed = err.downcast_ref::<WeatherPredictionFailedError>().unwrap();
        assert_eq!(failed.0, "daemon timeout");
    }

    #[test]
    fn map_weather_prediction_error_maps_storage_failed_to_failed() {
        let err = map_weather_prediction_error(WeatherPredictionError::WeatherDataStorageFailed(
            "disk full".into(),
        ));
        let failed = err.downcast_ref::<WeatherPredictionFailedError>().unwrap();
        assert_eq!(failed.0, "disk full");
    }
}
