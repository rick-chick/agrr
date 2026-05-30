//! Ruby: `Domain::CultivationPlan::Interactors::PlanAllocationAdjustInteractor`

use crate::cultivation_plan::dtos::{
    PlanAllocationAdjustFailure, PlanAllocationAdjustInput, PlanAllocationAdjustOutput,
    PlanAllocationAdjustReadSnapshot,
};
use crate::cultivation_plan::gateways::{
    AdjustWeatherPredictionGateway, CultivationPlanGateway, PlanAllocationAdjustDebugDumpGateway,
    PlanAllocationAdjustGateway, PlanAllocationAdjustReadGateway,
    CultivationPlanOptimizationEventsGateway,
};
use crate::cultivation_plan::interactors::rest_plan_access;
use crate::cultivation_plan::helpers::parse_iso_date;
use crate::cultivation_plan::mappers::{
    AgrrAdjustResultFieldCultivationSyncMapper, CropsConfigLogger,
    PlanAllocationAdjustAgrrPayloadMapper,
};
use crate::cultivation_plan::ports::{PlanAllocationAdjustInputPort, PlanAllocationAdjustOutputPort};
use crate::field_cultivation::errors::{
    FieldCultivationSyncDuplicateAllocationError, FieldCultivationSyncEmptyError,
    FieldCultivationSyncReferenceError, SyncReferenceKind,
};
use crate::field_cultivation::ports::FieldCultivationSyncInputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::ports::{ClockPort, LoggerPort, TranslatorPort};
use crate::weather_data::dtos::WeatherLocation;
use crate::weather_data::mappers::AdjustHistoricalPredictionMapper;
use crate::cultivation_plan::gateways::WeatherPredictionService;
use serde_json::{json, Value};
use time::Date;

pub struct PlanAllocationAdjustInteractor<'a, O, L, T, C, R, A, E, D, PG, WP, FCS> {
    output_port: &'a mut O,
    logger: &'a L,
    translator: &'a T,
    clock: &'a C,
    plan_gateway: &'a PG,
    read_gateway: &'a R,
    adjust_gateway: &'a A,
    optimization_events_gateway: &'a E,
    debug_dump_gateway: &'a D,
    weather_prediction_gateway: &'a WP,
    field_cultivation_sync: &'a mut FCS,
    interaction_rule_random_hex: &'a str,
    adjust_read_snapshot: Option<PlanAllocationAdjustReadSnapshot>,
}

impl<'a, O, L, T, C, R, A, E, D, PG, WP, FCS>
    PlanAllocationAdjustInteractor<'a, O, L, T, C, R, A, E, D, PG, WP, FCS>
where
    O: PlanAllocationAdjustOutputPort,
    L: LoggerPort,
    T: TranslatorPort,
    C: ClockPort,
    R: PlanAllocationAdjustReadGateway,
    A: PlanAllocationAdjustGateway,
    E: CultivationPlanOptimizationEventsGateway,
    D: PlanAllocationAdjustDebugDumpGateway,
    PG: CultivationPlanGateway,
    WP: AdjustWeatherPredictionGateway,
    FCS: FieldCultivationSyncInputPort + Send + Sync,
{
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        output_port: &'a mut O,
        logger: &'a L,
        translator: &'a T,
        clock: &'a C,
        plan_gateway: &'a PG,
        read_gateway: &'a R,
        adjust_gateway: &'a A,
        optimization_events_gateway: &'a E,
        debug_dump_gateway: &'a D,
        weather_prediction_gateway: &'a WP,
        field_cultivation_sync: &'a mut FCS,
        interaction_rule_random_hex: &'a str,
    ) -> Self {
        Self {
            output_port,
            logger,
            translator,
            clock,
            plan_gateway,
            read_gateway,
            adjust_gateway,
            optimization_events_gateway,
            debug_dump_gateway,
            weather_prediction_gateway,
            field_cultivation_sync,
            interaction_rule_random_hex,
            adjust_read_snapshot: None,
        }
    }

    fn emit_failure(&mut self, failure: PlanAllocationAdjustFailure) {
        self.output_port.on_failure(failure);
    }

    fn load_adjust_read_context(
        &mut self,
        plan_id: i64,
        auth: Option<&crate::cultivation_plan::dtos::CultivationPlanRestAuth>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Some(auth) = auth {
            let plan = self.plan_gateway.find_by_id(plan_id)?;
            if rest_plan_access::access_denied(&plan, auth) {
                return Err(Box::new(RecordNotFoundError));
            }
        }

        self.adjust_read_snapshot = Some(
            self.read_gateway
                .find_adjust_read_snapshot_by_plan_id(plan_id)?,
        );
        Ok(())
    }

    fn validate_plan_crop_growth_stages(&mut self) -> bool {
        let snapshot = self
            .adjust_read_snapshot
            .as_ref()
            .expect("snapshot loaded");
        for entry in &snapshot.plan_crop_snapshots {
            if entry.has_growth_stages {
                continue;
            }
            let mut opts = crate::shared::ports::translator_port::TranslateOptions::new();
            opts.insert("crop_name".into(), entry.crop_name.clone());
            let message = self
                .translator
                .translate("api.errors.cultivation_plan.crop_missing_growth_stages", &opts);
            self.emit_failure(PlanAllocationAdjustFailure {
                kind: PlanAllocationAdjustFailure::KIND_CROP_MISSING_GROWTH_STAGES.into(),
                message,
            });
            return false;
        }
        true
    }

    fn pass_rest_adjust_preflight(&mut self, input: &PlanAllocationAdjustInput) -> bool {
        match self.load_adjust_read_context(input.plan_id, input.auth.as_ref()) {
            Ok(()) => {}
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.emit_failure(PlanAllocationAdjustFailure {
                    kind: PlanAllocationAdjustFailure::KIND_NOT_FOUND.into(),
                    message: self.translator.translate(
                        "api.errors.common.not_found",
                        &crate::shared::ports::translator_port::TranslateOptions::new(),
                    ),
                });
                return false;
            }
            Err(err) => {
                self.logger.error(&format!("❌ [Adjust read] {err}"));
                self.emit_failure(PlanAllocationAdjustFailure {
                    kind: PlanAllocationAdjustFailure::KIND_UNEXPECTED.into(),
                    message: err.to_string(),
                });
                return false;
            }
        }

        self.validate_plan_crop_growth_stages()
    }

    fn weather_location_from_snapshot(
        snapshot: &PlanAllocationAdjustReadSnapshot,
    ) -> Option<WeatherLocation> {
        let wl = &snapshot.weather_prediction_targets.weather_location;
        if wl.is_null() {
            return None;
        }
        let id = wl.get("id")?.as_i64()?;
        let latitude = wl.get("latitude")?.as_f64()?;
        let longitude = wl.get("longitude")?.as_f64()?;
        let elevation = wl.get("elevation").and_then(|v| v.as_f64());
        let timezone = wl
            .get("timezone")
            .and_then(|v| v.as_str())
            .map(str::to_string);
        Some(WeatherLocation::new(
            id,
            latitude,
            longitude,
            elevation,
            timezone,
            None,
        ))
    }

    fn normalize_nested_weather_data(weather_data: Value) -> Value {
        crate::weather_data::helpers::normalize_nested_weather_data(weather_data)
    }

    fn clamp_planning_start_to_weather(
        &self,
        weather_data: &Value,
        effective_planning_start: Date,
    ) -> Date {
        let Some(weather_dates) = weather_data.get("data").and_then(|d| d.as_array()) else {
            return effective_planning_start;
        };
        if weather_dates.is_empty() {
            return effective_planning_start;
        }
        let Some(first_time) = weather_dates
            .first()
            .and_then(|d| d.get("time"))
            .and_then(|t| t.as_str())
        else {
            return effective_planning_start;
        };
        let Some(weather_start_date) = parse_iso_date(first_time) else {
            return effective_planning_start;
        };
        if effective_planning_start < weather_start_date {
            self.logger.info(&format!(
                "📅 [Adjust] Clamping planning_start from {effective_planning_start} to {weather_start_date} (weather data boundary)"
            ));
            weather_start_date
        } else {
            effective_planning_start
        }
    }

    fn extend_prediction_if_needed(
        &self,
        snapshot: &PlanAllocationAdjustReadSnapshot,
        prediction_service: &dyn WeatherPredictionService,
        weather_data: Value,
        effective_planning_end: Date,
        historical_rows: &[Value],
    ) -> Result<Value, PlanAllocationAdjustFailure> {
        let merged_dates: Vec<Date> = weather_data
            .get("data")
            .and_then(|d| d.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(|d| {
                        d.get("time")
                            .and_then(|t| t.as_str())
                            .and_then(parse_iso_date)
                    })
                    .collect()
            })
            .unwrap_or_default();
        let merged_end_date = merged_dates.iter().max().copied();

        if merged_end_date.is_some_and(|d| d >= effective_planning_end) {
            return Ok(weather_data);
        }

        self.logger.warn(&format!(
            "⚠️ [Adjust] Merged weather data ends at {:?}, but effective_planning_end is {effective_planning_end}. Extending prediction...",
            merged_end_date
        ));

        let plan_weather = &snapshot.cultivation_plan_weather_dto;
        let extended_prediction_data = prediction_service
            .predict_for_cultivation_plan(plan_weather, Some(effective_planning_end))
            .map_err(|e| PlanAllocationAdjustFailure {
                kind: PlanAllocationAdjustFailure::KIND_WEATHER_FETCH_FAILED.into(),
                message: self.translator.translate(
                    "api.errors.common.weather_fetch_failed",
                    &{
                        let mut opts = crate::shared::ports::translator_port::TranslateOptions::new();
                        opts.insert("message".into(), e.to_string());
                        opts
                    },
                ),
            })?;

        let new_weather = if historical_rows.is_empty() {
            extended_prediction_data
        } else {
            let facts = &snapshot.weather_location_facts;
            let latitude = facts
                .get("latitude")
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0);
            let longitude = facts
                .get("longitude")
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0);
            let elevation = facts.get("elevation").and_then(|v| v.as_f64()).unwrap_or(0.0);
            let timezone = facts
                .get("timezone")
                .and_then(|v| v.as_str())
                .unwrap_or("Asia/Tokyo");
            let current_year_formatted = AdjustHistoricalPredictionMapper::build_historical_agrr_series(
                latitude,
                longitude,
                elevation,
                timezone,
                historical_rows,
            );
            AdjustHistoricalPredictionMapper::merge_historical_series_with_prediction(
                &current_year_formatted,
                &extended_prediction_data,
            )
        };

        self.logger.info(&format!(
            "✅ [Adjust] Extended prediction data to cover until {effective_planning_end}"
        ));
        Ok(new_weather)
    }

    fn sync_reference_failure(
        &self,
        error: &FieldCultivationSyncReferenceError,
    ) -> PlanAllocationAdjustFailure {
        let message = match error.kind {
            SyncReferenceKind::FieldMissing => {
                let mut opts = crate::shared::ports::translator_port::TranslateOptions::new();
                opts.insert(
                    "field_id".into(),
                    error.field_id.map(|id| id.to_string()).unwrap_or_default(),
                );
                self.translator.translate(
                    "controllers.agrr_optimization.errors.field_missing",
                    &opts,
                )
            }
            SyncReferenceKind::PlanCropMissing => {
                let mut opts = crate::shared::ports::translator_port::TranslateOptions::new();
                opts.insert(
                    "crop_id".into(),
                    error.crop_id.clone().unwrap_or_default(),
                );
                self.translator.translate(
                    "controllers.agrr_optimization.errors.plan_crop_missing",
                    &opts,
                )
            }
            SyncReferenceKind::PlanCropAmbiguous => error.to_string(),
            SyncReferenceKind::StartDateInvalid => {
                let mut opts = crate::shared::ports::translator_port::TranslateOptions::new();
                opts.insert(
                    "value".into(),
                    error.raw_value.clone().unwrap_or_default(),
                );
                opts.insert(
                    "allocation_id".into(),
                    error.allocation_id.clone().unwrap_or_default(),
                );
                self.translator.translate(
                    "controllers.agrr_optimization.errors.start_date_invalid",
                    &opts,
                )
            }
            SyncReferenceKind::CompletionDateInvalid => {
                let mut opts = crate::shared::ports::translator_port::TranslateOptions::new();
                opts.insert(
                    "value".into(),
                    error.raw_value.clone().unwrap_or_default(),
                );
                opts.insert(
                    "allocation_id".into(),
                    error.allocation_id.clone().unwrap_or_default(),
                );
                self.translator.translate(
                    "controllers.agrr_optimization.errors.completion_date_invalid",
                    &opts,
                )
            }
        };

        PlanAllocationAdjustFailure {
            kind: PlanAllocationAdjustFailure::KIND_INVALID_DATE.into(),
            message,
        }
    }

    fn handle_field_cultivation_sync_error(
        &self,
        err: Box<dyn std::error::Error + Send + Sync>,
    ) -> PlanAllocationAdjustFailure {
        if let Some(ref_error) = err.downcast_ref::<FieldCultivationSyncReferenceError>() {
            self.logger.error(&format!(
                "❌ [Adjust] Field cultivation sync reference error: {ref_error}"
            ));
            return self.sync_reference_failure(ref_error);
        }
        if err.downcast_ref::<FieldCultivationSyncEmptyError>().is_some() {
            self.logger.error(&format!(
                "❌ [Adjust] Field cultivation sync validation failed: {err}"
            ));
            return PlanAllocationAdjustFailure {
                kind: PlanAllocationAdjustFailure::KIND_RESULT_EMPTY.into(),
                message: self.translator.translate(
                    "api.errors.optimization.result_empty",
                    &crate::shared::ports::translator_port::TranslateOptions::new(),
                ),
            };
        }
        if let Some(dup) = err.downcast_ref::<FieldCultivationSyncDuplicateAllocationError>() {
            self.logger.error(&format!(
                "❌ [Adjust] Field cultivation sync validation failed: {err}"
            ));
            let mut opts = crate::shared::ports::translator_port::TranslateOptions::new();
            opts.insert("ids".into(), dup.duplicate_ids.join(", "));
            return PlanAllocationAdjustFailure {
                kind: PlanAllocationAdjustFailure::KIND_UNEXPECTED.into(),
                message: self.translator.translate(
                    "controllers.agrr_optimization.errors.duplicate_allocation",
                    &opts,
                ),
            };
        }
        PlanAllocationAdjustFailure {
            kind: PlanAllocationAdjustFailure::KIND_UNEXPECTED.into(),
            message: err.to_string(),
        }
    }

    fn fetch_and_merge_weather_data(
        &self,
        snapshot: &PlanAllocationAdjustReadSnapshot,
        effective_planning_start: Date,
        effective_planning_end: Date,
    ) -> Result<Value, PlanAllocationAdjustFailure> {
        let weather_location = Self::weather_location_from_snapshot(snapshot).ok_or_else(|| {
            PlanAllocationAdjustFailure {
                kind: PlanAllocationAdjustFailure::KIND_WEATHER_FETCH_FAILED.into(),
                message: self.translator.translate(
                    "api.errors.common.weather_fetch_failed",
                    &{
                        let mut opts = crate::shared::ports::translator_port::TranslateOptions::new();
                        opts.insert(
                            "message".into(),
                            "気象データがありません。農場にWeatherLocationが設定されていません。"
                                .into(),
                        );
                        opts
                    },
                ),
            }
        })?;

        let prediction_service = self
            .weather_prediction_gateway
            .prediction_service(&weather_location, None)
            .map_err(|e| PlanAllocationAdjustFailure {
                kind: PlanAllocationAdjustFailure::KIND_WEATHER_FETCH_FAILED.into(),
                message: self.translator.translate(
                    "api.errors.common.weather_fetch_failed",
                    &{
                        let mut opts = crate::shared::ports::translator_port::TranslateOptions::new();
                        opts.insert("message".into(), e.to_string());
                        opts
                    },
                ),
            })?;

        let plan_weather = &snapshot.cultivation_plan_weather_dto;

        let prediction_data = if let Some(existing) =
            prediction_service.get_existing_prediction(effective_planning_end, plan_weather)
        {
            self.logger.info(&format!(
                "♻️ [Adjust] Using existing prediction data (target_end_date: {effective_planning_end})"
            ));
            existing
        } else {
            self.logger.info(&format!(
                "🔮 [Adjust] Generating new prediction data (target_end_date: {effective_planning_end})"
            ));
            prediction_service
                .predict_for_cultivation_plan(plan_weather, Some(effective_planning_end))
                .map_err(|e| {
                    let detail = e.to_string();
                    PlanAllocationAdjustFailure {
                        kind: PlanAllocationAdjustFailure::KIND_WEATHER_FETCH_FAILED.into(),
                        message: self.translator.translate(
                            "api.errors.common.weather_fetch_failed",
                            &{
                                let mut opts =
                                    crate::shared::ports::translator_port::TranslateOptions::new();
                                opts.insert("message".into(), detail);
                                opts
                            },
                        ),
                    }
                })?
        };

        let historical_end = self
            .clock
            .today()
            .checked_sub(time::Duration::days(1))
            .unwrap_or_else(|| self.clock.today());

        let historical_rows = self
            .read_gateway
            .list_historical_weather_rows(
                Some(weather_location.id),
                effective_planning_start,
                historical_end,
            )
            .map_err(|e| PlanAllocationAdjustFailure {
                kind: PlanAllocationAdjustFailure::KIND_WEATHER_FETCH_FAILED.into(),
                message: self.translator.translate(
                    "api.errors.common.weather_fetch_failed",
                    &{
                        let mut opts = crate::shared::ports::translator_port::TranslateOptions::new();
                        opts.insert("message".into(), e.to_string());
                        opts
                    },
                ),
            })?;

        let weather_data = if historical_rows.is_empty() {
            self.logger.warn(
                "⚠️ [Adjust] No historical weather data found. Proceeding with prediction data only.",
            );
            prediction_data
        } else {
            self.logger.info(&format!(
                "✅ [Adjust] Historical weather data loaded: {} records ({effective_planning_start} to {historical_end})",
                historical_rows.len()
            ));
            let facts = &snapshot.weather_location_facts;
            let latitude = facts
                .get("latitude")
                .and_then(|v| v.as_f64())
                .unwrap_or(weather_location.latitude);
            let longitude = facts
                .get("longitude")
                .and_then(|v| v.as_f64())
                .unwrap_or(weather_location.longitude);
            let elevation = facts
                .get("elevation")
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0);
            let timezone = facts
                .get("timezone")
                .and_then(|v| v.as_str())
                .unwrap_or("Asia/Tokyo");
            let current_year_formatted = AdjustHistoricalPredictionMapper::build_historical_agrr_series(
                latitude,
                longitude,
                elevation,
                timezone,
                &historical_rows,
            );
            let merged = AdjustHistoricalPredictionMapper::merge_historical_series_with_prediction(
                &current_year_formatted,
                &prediction_data,
            );
            let pred_days = prediction_data
                .get("data")
                .and_then(|d| d.as_array())
                .map(|a| a.len())
                .unwrap_or(0);
            self.logger.info(&format!(
                "✅ [Adjust] Merged weather data: historical={} records, prediction={pred_days} records",
                historical_rows.len()
            ));
            merged
        };

        self.extend_prediction_if_needed(
            snapshot,
            prediction_service.as_ref(),
            weather_data,
            effective_planning_end,
            &historical_rows,
        )
    }
}

impl<'a, O, L, T, C, R, A, E, D, PG, WP, FCS> PlanAllocationAdjustInputPort
    for PlanAllocationAdjustInteractor<'a, O, L, T, C, R, A, E, D, PG, WP, FCS>
where
    O: PlanAllocationAdjustOutputPort,
    L: LoggerPort,
    T: TranslatorPort,
    C: ClockPort,
    R: PlanAllocationAdjustReadGateway,
    A: PlanAllocationAdjustGateway,
    E: CultivationPlanOptimizationEventsGateway,
    D: PlanAllocationAdjustDebugDumpGateway,
    PG: CultivationPlanGateway,
    WP: AdjustWeatherPredictionGateway,
    FCS: FieldCultivationSyncInputPort + Send + Sync,
{
    fn call(
        &mut self,
        input: PlanAllocationAdjustInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if input.rest_adjust() && !self.pass_rest_adjust_preflight(&input) {
            return Ok(());
        }

        let perf_start = self.clock.now();
        self.logger
            .info(&format!("⏱️ [PERF] plan_allocation_adjust() 開始: {perf_start}"));

        if input.moves.is_empty() {
            self.logger
                .info("ℹ️ [Adjust] 移動指示が空のため調整をスキップします");
            self.output_port.on_success(PlanAllocationAdjustOutput {
                message: "調整不要（移動指示なし）".into(),
                skipped: true,
                payload: None,
                adjust_result: None,
            });
            return Ok(());
        }

        if self.adjust_read_snapshot.is_none() {
            self.load_adjust_read_context(input.plan_id, None)?;
        }

        let snapshot = self
            .adjust_read_snapshot
            .as_ref()
            .expect("snapshot loaded after load");

        let current_allocation =
            PlanAllocationAdjustAgrrPayloadMapper::to_current_allocation(snapshot, &[], self.logger);
        let fields = PlanAllocationAdjustAgrrPayloadMapper::to_fields_config(snapshot);
        let crops_logger = CropsConfigLogger(self.logger);
        let crops =
            PlanAllocationAdjustAgrrPayloadMapper::to_crops_config(snapshot, Some(&crops_logger));

        self.debug_dump_gateway.dump_payload(
            &current_allocation,
            &input.moves,
            &fields,
            &crops,
        );

        if snapshot.farm_without_weather_location {
            self.emit_failure(PlanAllocationAdjustFailure {
                kind: PlanAllocationAdjustFailure::KIND_NO_WEATHER_LOCATION.into(),
                message: self.translator.translate(
                    "api.errors.no_weather_data",
                    &crate::shared::ports::translator_port::TranslateOptions::new(),
                ),
            });
            return Ok(());
        }

        let cultivation_periods: Vec<crate::cultivation_plan::calculators::effective_planning_period_calculator::CultivationPeriodDate> = snapshot
            .cultivation_planning_periods
            .iter()
            .map(|p| crate::cultivation_plan::calculators::effective_planning_period_calculator::CultivationPeriodDate {
                start_date: p.start_date,
                completion_date: p.completion_date,
            })
            .collect();

        let (effective_start, effective_end) = match crate::cultivation_plan::calculators::effective_planning_period_calculator::calculate(
            &current_allocation,
            &input.moves,
            &cultivation_periods,
            snapshot.planning_period_boundaries.planning_start_date,
            snapshot.planning_period_boundaries.planning_end_date,
            self.clock.today(),
        ) {
            Ok(period) => period,
            Err(e) => {
                self.logger.error(&format!("❌ [Adjust] planning period: {e}"));
                self.emit_failure(PlanAllocationAdjustFailure {
                    kind: PlanAllocationAdjustFailure::KIND_INVALID_DATE.into(),
                    message: self.translator.translate(
                        "api.errors.common.invalid_date_format",
                        &crate::shared::ports::translator_port::TranslateOptions::new(),
                    ),
                });
                return Ok(());
            }
        };

        let weather_data = match self.fetch_and_merge_weather_data(
            snapshot,
            effective_start,
            effective_end,
        ) {
            Ok(data) => data,
            Err(failure) => {
                self.emit_failure(failure);
                return Ok(());
            }
        };

        let weather_data = Self::normalize_nested_weather_data(weather_data);

        let interaction_rules = PlanAllocationAdjustAgrrPayloadMapper::to_interaction_rules(
            snapshot,
            self.interaction_rule_random_hex,
        );
        let interaction_rules_value = if interaction_rules.is_empty() {
            None
        } else {
            Some(json!({ "rules": interaction_rules }))
        };

        let (mut effective_start, effective_end) = match crate::cultivation_plan::calculators::effective_planning_period_calculator::calculate(
            &current_allocation,
            &input.moves,
            &cultivation_periods,
            snapshot.planning_period_boundaries.planning_start_date,
            snapshot.planning_period_boundaries.planning_end_date,
            self.clock.today(),
        ) {
            Ok(period) => period,
            Err(e) => {
                self.logger.error(&format!("❌ [Adjust] planning period: {e}"));
                self.emit_failure(PlanAllocationAdjustFailure {
                    kind: PlanAllocationAdjustFailure::KIND_INVALID_DATE.into(),
                    message: self.translator.translate(
                        "api.errors.common.invalid_date_format",
                        &crate::shared::ports::translator_port::TranslateOptions::new(),
                    ),
                });
                return Ok(());
            }
        };

        effective_start = self.clamp_planning_start_to_weather(&weather_data, effective_start);

        self.logger.info(&format!(
            "📅 [Adjust] 計画期間: {effective_start} 〜 {effective_end} (制約として使用しない)"
        ));

        match self.adjust_gateway.adjust(
            &current_allocation,
            &input.moves,
            &fields,
            &crops,
            &weather_data,
            effective_start,
            effective_end,
            interaction_rules_value.as_ref(),
            "maximize_profit",
            None,
            true,
        ) {
            Ok(result) => {
                let has_schedules = result
                    .get("field_schedules")
                    .map(|v| !v.as_array().map(|a| a.is_empty()).unwrap_or(true))
                    .unwrap_or(false);
                if !has_schedules {
                    self.emit_failure(PlanAllocationAdjustFailure {
                        kind: PlanAllocationAdjustFailure::KIND_RESULT_EMPTY.into(),
                        message: self.translator.translate(
                            "api.errors.optimization.result_empty",
                            &crate::shared::ports::translator_port::TranslateOptions::new(),
                        ),
                    });
                    return Ok(());
                }

                let sync_input = AgrrAdjustResultFieldCultivationSyncMapper::to_sync_input(&result);
                if let Err(err) = self
                    .field_cultivation_sync
                    .call(input.plan_id, sync_input)
                {
                    self.emit_failure(self.handle_field_cultivation_sync_error(err));
                    return Ok(());
                }

                let summary = self
                    .read_gateway
                    .plan_summary_for_adjust_response(input.plan_id)?;
                let mut payload = summary;
                if let Some(profit) = result.get("total_profit") {
                    if let Some(obj) = payload.as_object_mut() {
                        obj.insert("total_profit".into(), profit.clone());
                    }
                }
                self.optimization_events_gateway
                    .broadcast_optimization_complete(input.plan_id, "adjusted")?;
                self.output_port.on_success(PlanAllocationAdjustOutput {
                    message: self.translator.translate(
                        "optimization.messages.adjust_completed",
                        &crate::shared::ports::translator_port::TranslateOptions::new(),
                    ),
                    skipped: false,
                    payload: Some(payload),
                    adjust_result: Some(result),
                });
                Ok(())
            }
            Err(e) => {
                self.logger.error(&format!("❌ [Adjust] Failed to adjust: {e}"));
                let mut opts = crate::shared::ports::translator_port::TranslateOptions::new();
                opts.insert("message".into(), e.to_string());
                self.emit_failure(PlanAllocationAdjustFailure {
                    kind: PlanAllocationAdjustFailure::KIND_ADJUST_EXECUTION_FAILED.into(),
                    message: self.translator.translate(
                        "api.errors.optimization.adjust_failed",
                        &opts,
                    ),
                });
                Ok(())
            }
        }
    }
}

#[cfg(test)]
mod interactors_plan_allocation_adjust_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_plan_allocation_adjust_interactor_test.rs"));
}
