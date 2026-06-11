//! Ruby: `Domain::CultivationPlan::Interactors::CultivationPlanOptimizeInteractor`
//!
//! **天気**: allocate 中は新規 `predict` しない。`get_existing_prediction` で DB キャッシュのみ読む
//! （Rails 同様）。新規予測はチェーンの `WeatherPredictionJob` / `run_weather_prediction_step` 側。
//! 天気予測の日数は `OptimizationJobChainWeatherComputation`（Rails `WeatherPredictionJob` 相当）。

use std::fmt;

use serde_json::Value;
use time::Date;

use crate::cultivation_plan::calculators::OptimizationAllocationInputCalculator;
use crate::cultivation_plan::dtos::{
    CultivationPlanPhaseName, FieldCultivationCreateAttrs, FieldCultivationOptimizationPersist,
    OptimizationApplyAttrs, OptimizationPlanSnapshot,
};
use crate::weather_data::dtos::CultivationPlanWeather;
use crate::cultivation_plan::errors::{
    AllocationExecutionError, AllocationNoCandidatesError, CultivationPlanCropMissingError,
};
use crate::cultivation_plan::gateways::{
    AdjustWeatherPredictionGateway, CultivationPlanOptimizationGateway,
    InteractionRulePlanReadGateway, OptimizationPlanReadGateway, PlanAllocationAllocateGateway,
};
use crate::cultivation_plan::mappers::{
    interaction_rule_agrr_mapper, optimization_plan_read_snapshot_mapper,
};
use crate::cultivation_plan::policies::cultivation_plan_allocate_allocation_policy;
use crate::cultivation_plan::ports::CultivationPlanOptimizeAdvancePhasePort;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::ports::ClockPort;
use crate::shared::ports::LoggerPort;
use crate::weather_data::helpers::{normalize_nested_weather_data, parse_iso_date};

#[derive(Debug, Clone, PartialEq)]
pub struct WeatherDataNotFoundError {
    pub message: String,
}

impl fmt::Display for WeatherDataNotFoundError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for WeatherDataNotFoundError {}

pub struct CultivationPlanOptimizeInteractor<'a> {
    plan_id: i64,
    channel_class: String,
    allocate_gateway: &'a dyn PlanAllocationAllocateGateway,
    interaction_rule_gateway: &'a dyn InteractionRulePlanReadGateway,
    optimization_gateway: &'a dyn CultivationPlanOptimizationGateway,
    optimization_plan_read_gateway: &'a dyn OptimizationPlanReadGateway,
    advance_phase: &'a dyn CultivationPlanOptimizeAdvancePhasePort,
    weather_prediction_gateway: &'a dyn AdjustWeatherPredictionGateway,
    logger: &'a dyn LoggerPort,
    clock: &'a dyn ClockPort,
}

impl<'a> CultivationPlanOptimizeInteractor<'a> {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        plan_id: i64,
        channel_class: impl Into<String>,
        allocate_gateway: &'a dyn PlanAllocationAllocateGateway,
        interaction_rule_gateway: &'a dyn InteractionRulePlanReadGateway,
        optimization_gateway: &'a dyn CultivationPlanOptimizationGateway,
        optimization_plan_read_gateway: &'a dyn OptimizationPlanReadGateway,
        advance_phase: &'a dyn CultivationPlanOptimizeAdvancePhasePort,
        weather_prediction_gateway: &'a dyn AdjustWeatherPredictionGateway,
        logger: &'a dyn LoggerPort,
        clock: &'a dyn ClockPort,
    ) -> Self {
        Self {
            plan_id,
            channel_class: channel_class.into(),
            allocate_gateway,
            interaction_rule_gateway,
            optimization_gateway,
            optimization_plan_read_gateway,
            advance_phase,
            weather_prediction_gateway,
            logger,
            clock,
        }
    }

    pub fn call(&self) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
        let snapshot = optimization_plan_read_snapshot_mapper::load_snapshot(
            self.optimization_plan_read_gateway,
            self.plan_id,
        )?;

        self.advance_phase(CultivationPlanPhaseName::PhaseOptimizing, None);

        if !snapshot.weather_location_present {
            let message =
                "農場にWeatherLocationが設定されていません。気象データを取得してください。".to_string();
            self.logger.error(&format!("❌ [Optimizer] {message}"));
            return Err(Box::new(WeatherDataNotFoundError { message }));
        }

        let (_, planning_end_date) = self.calculate_planning_period(&snapshot)?;

        let weather_location = snapshot
            .weather_location_input
            .as_ref()
            .ok_or_else(|| {
                Box::new(WeatherDataNotFoundError {
                    message: "農場にWeatherLocationが設定されていません。気象データを取得してください。"
                        .into(),
                }) as Box<dyn std::error::Error + Send + Sync>
            })?;

        let prediction_service = self
            .weather_prediction_gateway
            .prediction_service(weather_location)?;

        let plan_weather = CultivationPlanWeather::new(
            snapshot.plan_id,
            snapshot.prediction_target_end_date,
            snapshot.calculated_planning_end_date,
            snapshot.plan_metadata.clone(),
        );

        let weather_data = prediction_service
            .get_existing_prediction(planning_end_date, &plan_weather)
            .ok_or_else(|| {
                let message =
                    "天気予測データが存在しません。計画作成時に天気予測が実行されていません。";
                self.logger.error(&format!("❌ [Optimizer] {message}"));
                Box::new(WeatherDataNotFoundError {
                    message: message.into(),
                }) as Box<dyn std::error::Error + Send + Sync>
            })?;
        let weather_data = normalize_nested_weather_data(weather_data);
        let weather_days = weather_data
            .get("data")
            .and_then(|d| d.as_array())
            .map(|a| a.len())
            .unwrap_or(0);
        if weather_days == 0 {
            let message =
                "天気予測データが存在しません。計画作成時に天気予測が実行されていません。";
            self.logger.error(&format!("❌ [Optimizer] {message} (empty data rows)"));
            return Err(Box::new(WeatherDataNotFoundError {
                message: message.into(),
            }));
        }

        self.logger.info(&format!(
            "♻️ [Optimizer] Using existing prediction data (days={weather_days})"
        ));

        let total_area = snapshot.total_area.unwrap_or(0.0);
        let plan_crops = self
            .optimization_gateway
            .cultivation_plan_crops_with_crop(self.plan_id)?;

        let (fields_data, crops_data) =
            OptimizationAllocationInputCalculator::build(total_area, &plan_crops, self.logger);

        let interaction_rules = self.prepare_interaction_rules()?;

        self.logger.info(&format!(
            "🚀 [AGRR] Starting single allocation for {} fields and {} crops",
            fields_data.len(),
            crops_data.len()
        ));
        if let Some(ref rules) = interaction_rules {
            if rules.as_array().is_some_and(|a| !a.is_empty()) {
                let count = rules.as_array().map(|a| a.len()).unwrap_or(0);
                self.logger
                    .info(&format!("📋 [AGRR] Using {count} interaction rules"));
            }
        }

        let (planning_start, planning_end) = self.calculate_planning_period(&snapshot)?;

        let rules_ref = interaction_rules.as_ref();
        let allocation_result = self
            .allocate_gateway
            .allocate(
                &fields_data,
                &crops_data,
                &weather_data,
                planning_start,
                planning_end,
                rules_ref,
                "maximize_profit",
                None,
                false,
            )
            .map_err(|e| Self::map_allocate_error(e))?;

        if !cultivation_plan_allocate_allocation_policy::allocation_result_persistable(
            &allocation_result,
        ) {
            return Err(Box::new(AllocationNoCandidatesError::new(
                "allocation result has no persistable field_schedules (agrr allocate rows must include growth_days, crop_name, and cultivation dates)",
            )));
        }

        self.distribute_allocation_results(&allocation_result)?;
        self.update_cultivation_plan_with_results(&allocation_result)?;

        self.logger
            .info(&format!("✅ CultivationPlan #{} optimization completed", self.plan_id));
        Ok(true)
    }

    pub(crate) fn calculate_planning_period(
        &self,
        snapshot: &OptimizationPlanSnapshot,
    ) -> Result<(Date, Date), Box<dyn std::error::Error + Send + Sync>> {
        let today = self.clock.today();

        if self
            .optimization_gateway
            .field_cultivations_with_allocate_results_present(self.plan_id)?
        {
            let start = snapshot
                .calculated_planning_start_date
                .ok_or("calculated_planning_start_date missing")?;
            let end = snapshot
                .calculated_planning_end_date
                .ok_or("calculated_planning_end_date missing")?;
            return Ok((start, end));
        }

        if snapshot.plan_type_private {
            let start = Date::from_calendar_date(today.year(), time::Month::January, 1)
                .map_err(|e| e.to_string())?;
            let end = Date::from_calendar_date(today.year() + 1, time::Month::December, 31)
                .map_err(|e| e.to_string())?;
            return Ok((start, end));
        }

        let end = snapshot
            .prediction_target_end_date
            .unwrap_or_else(|| {
                Date::from_calendar_date(today.year() + 1, time::Month::December, 31)
                    .unwrap_or(today)
            });
        Ok((today, end))
    }

    fn prepare_interaction_rules(
        &self,
    ) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>> {
        let rules = self
            .interaction_rule_gateway
            .list_by_cultivation_plan_id(self.plan_id)?;
        if rules.is_empty() {
            return Ok(None);
        }
        Ok(Some(Value::Array(
            interaction_rule_agrr_mapper::to_agrr_format_array(&rules),
        )))
    }

    fn distribute_allocation_results(
        &self,
        allocation_result: &Value,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.optimization_gateway
            .clear_field_cultivations(self.plan_id)?;
        self.logger.info(&format!(
            "🗑️  [AGRR] Cleared existing FieldCultivations for CultivationPlan #{}",
            self.plan_id
        ));
        self.logger.info(&format!(
            "🔄 [AGRR] Keeping existing CultivationPlanFields and CultivationPlanCrops for CultivationPlan #{}",
            self.plan_id
        ));

        let field_schedules = allocation_result
            .get("field_schedules")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();

        for schedule in &field_schedules {
            let field_id = schedule.get("field_id").map(field_id_to_string).unwrap_or_default();
            let allocations = schedule
                .get("allocations")
                .and_then(|v| v.as_array())
                .cloned()
                .unwrap_or_default();

            if allocations.is_empty() {
                self.logger
                    .warn(&format!("⚠️  [AGRR] No allocations for field {field_id}"));
                continue;
            }

            let mut persisted = 0usize;
            for allocation in &allocations {
                if !cultivation_plan_allocate_allocation_policy::allocation_row_persistable(
                    allocation,
                ) {
                    self.logger.warn(&format!(
                        "⚠️  [AGRR] Skipping non-persistable allocation for field {field_id}"
                    ));
                    continue;
                }
                self.create_field_cultivation_from_allocation(allocation, &field_id)?;
                persisted += 1;
            }

            if persisted == 0 {
                return Err(Box::new(AllocationNoCandidatesError::new(
                    "no persistable allocations in field schedule",
                )));
            }

            self.logger.info(&format!(
                "✅ [AGRR] Created {persisted} FieldCultivations for field {field_id}"
            ));
        }
        Ok(())
    }

    fn create_field_cultivation_from_allocation(
        &self,
        allocation: &Value,
        field_id: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let crop_id = parse_crop_id_from_allocation(allocation)?;
        let crop_name = allocation
            .get("crop_name")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();

        let field_number = field_id.split('_').next_back().unwrap_or(field_id);
        let field_name = field_number.to_string();

        let area_used = allocation
            .get("area_used")
            .and_then(|v| v.as_f64())
            .unwrap_or(0.0);

        let plan_field_id = self.optimization_gateway.upsert_cultivation_plan_field(
            self.plan_id,
            &field_name,
            area_used,
            10.0,
        )?;

        let plan_crop_id = self
            .optimization_gateway
            .find_crop_id(self.plan_id, crop_id)
            .map_err(|e| {
                if e.downcast_ref::<CultivationPlanCropMissingError>().is_some() {
                    e
                } else {
                    Box::new(CultivationPlanCropMissingError::new(e.to_string()))
                        as Box<dyn std::error::Error + Send + Sync>
                }
            })?;

        let start_date = allocation
            .get("start_date")
            .and_then(|v| v.as_str())
            .and_then(parse_iso_date)
            .ok_or("allocation start_date missing")?;
        let completion_date = allocation
            .get("completion_date")
            .and_then(|v| v.as_str())
            .and_then(parse_iso_date)
            .ok_or("allocation completion_date missing")?;

        let cultivation_days = allocation
            .get("growth_days")
            .and_then(|v| v.as_i64())
            .map(|d| d as i32)
            .unwrap_or_else(|| (completion_date - start_date).whole_days() as i32 + 1);

        let estimated_cost = allocation
            .get("total_cost")
            .and_then(|v| v.as_f64())
            .unwrap_or(0.0);

        let optimization_persist = FieldCultivationOptimizationPersist::new(
            allocation
                .get("allocation_id")
                .and_then(|v| v.as_i64())
                .unwrap_or(0),
            allocation
                .get("expected_revenue")
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0),
            allocation
                .get("profit")
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0),
            allocation.clone(),
        );

        let attrs = FieldCultivationCreateAttrs::new(
            plan_field_id,
            plan_crop_id,
            area_used,
            start_date,
            completion_date,
            cultivation_days,
            estimated_cost,
            "completed",
            optimization_persist,
        );

        self.optimization_gateway
            .create_field_cultivation(self.plan_id, attrs)?;

        self.logger.info(&format!(
            "🌱 [AGRR] Created FieldCultivation for {crop_name} {start_date} - {completion_date} ({area_used}㎡)"
        ));
        Ok(())
    }

    fn update_cultivation_plan_with_results(
        &self,
        allocation_result: &Value,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let summary = allocation_result
            .get("summary")
            .map(|s| s.to_string())
            .unwrap_or_else(|| "null".to_string());

        let attrs = OptimizationApplyAttrs::new(
            pick_f64(allocation_result, "total_profit"),
            pick_f64(allocation_result, "total_revenue"),
            pick_f64(allocation_result, "total_cost"),
            pick_f64(allocation_result, "optimization_time"),
            pick_string(allocation_result, "algorithm_used").unwrap_or_else(|| "unknown".into()),
            pick_bool(allocation_result, "is_optimal").unwrap_or(false),
            summary,
        );

        self.optimization_gateway
            .apply_optimization_result(self.plan_id, attrs)?;

        self.logger.info(&format!(
            "📊 [AGRR] CultivationPlan #{} updated with optimization results: profit=¥{}, revenue=¥{}, cost=¥{}",
            self.plan_id,
            pick_f64(allocation_result, "total_profit"),
            pick_f64(allocation_result, "total_revenue"),
            pick_f64(allocation_result, "total_cost"),
        ));
        Ok(())
    }

    fn advance_phase(
        &self,
        phase_name: CultivationPlanPhaseName,
        failure_subphase: Option<&str>,
    ) {
        self.advance_phase.advance(
            self.plan_id,
            &self.channel_class,
            phase_name,
            failure_subphase,
        );
    }

    pub fn map_allocate_error(
        err: Box<dyn std::error::Error + Send + Sync>,
    ) -> Box<dyn std::error::Error + Send + Sync> {
        if err.downcast_ref::<AllocationNoCandidatesError>().is_some()
            || err.downcast_ref::<AllocationExecutionError>().is_some()
            || err.downcast_ref::<WeatherDataNotFoundError>().is_some()
            || err.downcast_ref::<CultivationPlanCropMissingError>().is_some()
            || err.downcast_ref::<RecordInvalidError>().is_some()
        {
            return err;
        }
        err
    }
}

fn field_id_to_string(v: &Value) -> String {
    v.as_str()
        .map(str::to_string)
        .or_else(|| v.as_i64().map(|n| n.to_string()))
        .unwrap_or_default()
}

fn parse_crop_id_from_allocation(
    allocation: &Value,
) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
    if let Some(n) = allocation.get("crop_id").and_then(|v| v.as_i64()) {
        return Ok(n);
    }
    if let Some(s) = allocation.get("crop_id").and_then(|v| v.as_str()) {
        return s
            .parse()
            .map_err(|e| format!("invalid crop_id: {e}").into());
    }
    Err("allocation crop_id missing".into())
}

fn pick_f64(h: &Value, key: &str) -> f64 {
    h.get(key).and_then(|v| v.as_f64()).unwrap_or(0.0)
}

fn pick_string(h: &Value, key: &str) -> Option<String> {
    h.get(key)
        .and_then(|v| v.as_str())
        .map(str::to_string)
}

fn pick_bool(h: &Value, key: &str) -> Option<bool> {
    h.get(key).and_then(|v| v.as_bool())
}

#[cfg(test)]
mod interactors_cultivation_plan_optimize_interactor_test_inline {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/interactors_cultivation_plan_optimize_interactor_test.rs"
    ));
}
