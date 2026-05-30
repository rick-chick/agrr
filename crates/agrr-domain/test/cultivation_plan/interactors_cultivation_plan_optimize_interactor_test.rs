// Ruby: test/domain/cultivation_plan/interactors/cultivation_plan_optimize_interactor_test.rb

use super::CultivationPlanOptimizeInteractor;
use crate::cultivation_plan::dtos::OptimizationPlanSnapshot;
use crate::cultivation_plan::gateways::{
    AdjustWeatherPredictionGateway, CultivationPlanOptimizationGateway,
    InteractionRulePlanReadGateway, OptimizationPlanReadGateway, PlanAllocationAllocateGateway,
};
use crate::cultivation_plan::ports::CultivationPlanOptimizeAdvancePhasePort;
use crate::shared::ports::{ClockPort, LoggerPort};
use crate::weather_data::dtos::{FarmWeatherPrediction, WeatherLocation};
use time::{Date, Month, OffsetDateTime};

struct FixedClock(Date);

impl ClockPort for FixedClock {
    fn today(&self) -> Date {
        self.0
    }

    fn now(&self) -> OffsetDateTime {
        self.0
            .with_hms(0, 0, 0)
            .unwrap()
            .assume_utc()
    }
}

struct StubOptimizationGateway {
    field_cultivations_present: bool,
}

impl CultivationPlanOptimizationGateway for StubOptimizationGateway {
    fn field_cultivations_present(
        &self,
        _plan_id: i64,
    ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.field_cultivations_present)
    }

    fn cultivation_plan_crops_with_crop(
        &self,
        _plan_id: i64,
    ) -> Result<Vec<crate::cultivation_plan::dtos::CultivationPlanCropWithAgrr>, Box<dyn std::error::Error + Send + Sync>>
    {
        Ok(vec![])
    }

    fn clear_field_cultivations(
        &self,
        _plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Ok(())
    }

    fn create_field_cultivation(
        &self,
        _plan_id: i64,
        _attrs: crate::cultivation_plan::dtos::FieldCultivationCreateAttrs,
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
        Ok(0)
    }

    fn upsert_cultivation_plan_field(
        &self,
        _plan_id: i64,
        _name: &str,
        _area: f64,
        _daily_fixed_cost: f64,
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
        Ok(0)
    }

    fn find_crop_id(
        &self,
        _plan_id: i64,
        _crop_id: i64,
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
        Ok(0)
    }

    fn apply_optimization_result(
        &self,
        _plan_id: i64,
        _attrs: crate::cultivation_plan::dtos::OptimizationApplyAttrs,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Ok(())
    }

    fn update_predicted_weather_data(
        &self,
        _cultivation_plan_id: i64,
        _payload: serde_json::Value,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Ok(())
    }
}

struct SilentLogger;
impl LoggerPort for SilentLogger {
    fn info(&self, _: &str) {}
    fn warn(&self, _: &str) {}
    fn error(&self, _: &str) {}
    fn debug(&self, _: &str) {}
}

struct PanicAllocate;
impl PlanAllocationAllocateGateway for PanicAllocate {
    fn allocate(
        &self,
        _: &[serde_json::Value],
        _: &[serde_json::Value],
        _: &serde_json::Value,
        _: Date,
        _: Date,
        _: Option<&serde_json::Value>,
        _: &str,
        _: Option<i64>,
        _: bool,
    ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
        panic!("not used in this test");
    }
}

struct PanicRules;
impl InteractionRulePlanReadGateway for PanicRules {
    fn list_by_cultivation_plan_id(
        &self,
        _: i64,
    ) -> Result<Vec<crate::interaction_rule::entities::InteractionRuleEntity>, Box<dyn std::error::Error + Send + Sync>>
    {
        panic!("not used");
    }
}

struct PanicRead;
impl OptimizationPlanReadGateway for PanicRead {
    fn find_optimization_plan_core_snapshot_by_plan_id(
        &self,
        _: i64,
    ) -> Result<
        crate::cultivation_plan::dtos::OptimizationPlanReadPlanCoreSnapshot,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        panic!("not used");
    }

    fn find_optimization_weather_location_by_plan_id(
        &self,
        _: i64,
    ) -> Result<Option<WeatherLocation>, Box<dyn std::error::Error + Send + Sync>> {
        panic!("not used");
    }

    fn find_optimization_farm_weather_by_plan_id(
        &self,
        _: i64,
    ) -> Result<Option<FarmWeatherPrediction>, Box<dyn std::error::Error + Send + Sync>> {
        panic!("not used");
    }
}

struct PanicAdvance;
impl CultivationPlanOptimizeAdvancePhasePort for PanicAdvance {
    fn advance(
        &self,
        _: i64,
        _: &str,
        _: crate::cultivation_plan::dtos::CultivationPlanPhaseName,
        _: Option<&str>,
    ) {
    }
}

struct PanicWeather;
impl AdjustWeatherPredictionGateway for PanicWeather {
    fn prediction_service(
        &self,
        _: &WeatherLocation,
        _: Option<&FarmWeatherPrediction>,
    ) -> Result<Box<dyn crate::cultivation_plan::gateways::WeatherPredictionService>, Box<dyn std::error::Error + Send + Sync>>
    {
        panic!("not used");
    }
}

#[test]
fn calculate_planning_period_uses_prediction_target_end_for_public_plan_without_field_cultivations(
) {
    let fixed_today = Date::from_calendar_date(2026, Month::July, 20).unwrap();
    let target_end = Date::from_calendar_date(2027, Month::December, 31).unwrap();
    let snapshot = OptimizationPlanSnapshot {
        plan_id: 42,
        plan_type_private: false,
        calculated_planning_start_date: None,
        calculated_planning_end_date: None,
        prediction_target_end_date: Some(target_end),
        predicted_weather_data: None,
        total_area: Some(0.0),
        weather_location_present: true,
        weather_location_input: Some(WeatherLocation::new(
            1,
            0.0,
            0.0,
            Some(0.0),
            Some("UTC".into()),
            None,
        )),
        farm_weather_input: None,
    };
    let gateway = StubOptimizationGateway {
        field_cultivations_present: false,
    };
    let clock = FixedClock(fixed_today);
    let interactor = CultivationPlanOptimizeInteractor::new(
        42,
        "OptimizationChannel",
        &PanicAllocate,
        &PanicRules,
        &gateway,
        &PanicRead,
        &PanicAdvance,
        &PanicWeather,
        &SilentLogger,
        &clock,
    );
    let (start, end) = interactor
        .calculate_planning_period(&snapshot)
        .expect("planning period");
    assert_eq!(start, fixed_today);
    assert_eq!(end, target_end);
}
