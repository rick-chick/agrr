//! Ruby: `Domain::CultivationPlan::Dtos::AdvanceCultivationPlanPhaseInput`

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CultivationPlanPhaseName {
    StartOptimizing,
    PhaseFetchingWeather,
    PhaseWeatherDataFetched,
    PhasePredictingWeather,
    PhaseWeatherPredictionCompleted,
    PhaseOptimizationCompleted,
    PhaseOptimizing,
    PhaseTaskScheduleGenerating,
    PhaseCompleted,
    PhaseFailed,
}

impl CultivationPlanPhaseName {
    pub fn parse(s: &str) -> Result<Self, String> {
        match s {
            "start_optimizing" => Ok(Self::StartOptimizing),
            "phase_fetching_weather" => Ok(Self::PhaseFetchingWeather),
            "phase_weather_data_fetched" => Ok(Self::PhaseWeatherDataFetched),
            "phase_predicting_weather" => Ok(Self::PhasePredictingWeather),
            "phase_weather_prediction_completed" => Ok(Self::PhaseWeatherPredictionCompleted),
            "phase_optimization_completed" => Ok(Self::PhaseOptimizationCompleted),
            "phase_optimizing" => Ok(Self::PhaseOptimizing),
            "phase_task_schedule_generating" => Ok(Self::PhaseTaskScheduleGenerating),
            "phase_completed" => Ok(Self::PhaseCompleted),
            "phase_failed" => Ok(Self::PhaseFailed),
            other => Err(format!("Unknown cultivation plan phase: {other:?}")),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AdvanceCultivationPlanPhaseInput {
    pub plan_id: i64,
    pub phase_name: CultivationPlanPhaseName,
    pub channel_class: Option<String>,
    pub failure_subphase: Option<String>,
}
