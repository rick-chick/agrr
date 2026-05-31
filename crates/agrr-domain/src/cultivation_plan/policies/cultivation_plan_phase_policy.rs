//! Ruby: `Domain::CultivationPlan::Policies::CultivationPlanPhasePolicy`

use std::collections::HashMap;

use crate::cultivation_plan::dtos::CultivationPlanPhaseName;

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanPhaseBuild {
    pub attrs: HashMap<String, String>,
    pub message_key: Option<String>,
    pub broadcast: bool,
}

pub fn build(phase_name: CultivationPlanPhaseName, failure_subphase: Option<&str>) -> CultivationPlanPhaseBuild {
    match phase_name {
        CultivationPlanPhaseName::StartOptimizing => CultivationPlanPhaseBuild {
            attrs: HashMap::from([
                ("status".into(), "optimizing".into()),
                ("optimization_phase".into(), "optimizing".into()),
                ("optimization_phase_message".into(), String::new()),
            ]),
            message_key: None,
            broadcast: false,
        },
        CultivationPlanPhaseName::PhaseFetchingWeather => {
            phase_attrs("fetching_weather", "models.cultivation_plan.phases.fetching_weather")
        }
        CultivationPlanPhaseName::PhaseWeatherDataFetched => phase_attrs(
            "weather_data_fetched",
            "models.cultivation_plan.phases.weather_data_fetched",
        ),
        CultivationPlanPhaseName::PhasePredictingWeather => {
            phase_attrs("predicting_weather", "models.cultivation_plan.phases.predicting_weather")
        }
        CultivationPlanPhaseName::PhaseWeatherPredictionCompleted => phase_attrs(
            "weather_prediction_completed",
            "models.cultivation_plan.phases.weather_prediction_completed",
        ),
        CultivationPlanPhaseName::PhaseOptimizationCompleted => phase_attrs(
            "optimization_completed",
            "models.cultivation_plan.phases.optimization_completed",
        ),
        CultivationPlanPhaseName::PhaseOptimizing => {
            phase_attrs("optimizing", "models.cultivation_plan.phases.optimizing")
        }
        CultivationPlanPhaseName::PhaseTaskScheduleGenerating => phase_attrs(
            "task_schedule_generating",
            "models.cultivation_plan.phases.task_schedule_generating",
        ),
        CultivationPlanPhaseName::PhaseCompleted => {
            phase_attrs("completed", "models.cultivation_plan.phases.completed")
        }
        CultivationPlanPhaseName::PhaseFailed => CultivationPlanPhaseBuild {
            attrs: HashMap::from([
                ("optimization_phase".into(), "failed".into()),
                ("status".into(), "failed".into()),
            ]),
            message_key: Some(failure_message_key(failure_subphase).into()),
            broadcast: true,
        },
    }
}

fn phase_attrs(phase: &str, message_key: &str) -> CultivationPlanPhaseBuild {
    CultivationPlanPhaseBuild {
        attrs: HashMap::from([("optimization_phase".into(), phase.into())]),
        message_key: Some(message_key.into()),
        broadcast: true,
    }
}

fn failure_message_key(failure_subphase: Option<&str>) -> &'static str {
    match failure_subphase.unwrap_or("") {
        "fetching_weather" => "models.cultivation_plan.phase_failed.fetching_weather",
        "predicting_weather" => "models.cultivation_plan.phase_failed.predicting_weather",
        "optimizing" => "models.cultivation_plan.phase_failed.optimizing",
        "task_schedule_generation" => "models.cultivation_plan.phase_failed.task_schedule_generation",
        _ => "models.cultivation_plan.phase_failed.default",
    }
}
