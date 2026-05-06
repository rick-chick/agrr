# frozen_string_literal: true

# 計画関連 ActiveJob が rescue に使う例外の集合（Application edge 3: 広い rescue StandardError の代替）。
module CultivationPlanJobExceptions
  SHARED_PERSISTENCE_FAILURES = [
    ActiveRecord::RecordNotFound,
    ActiveRecord::RecordInvalid,
    Domain::Shared::Exceptions::RecordNotFound,
    Domain::Shared::Exceptions::RecordInvalid
  ].freeze

  OPTIMIZATION_FAILURES = (
    SHARED_PERSISTENCE_FAILURES + [
      Domain::CultivationPlan::Interactors::CultivationPlanOptimizeInteractor::WeatherDataNotFoundError,
      Domain::CultivationPlan::Errors::AllocationNoCandidatesError,
      Domain::CultivationPlan::Errors::AllocationExecutionError,
      Domain::CultivationPlan::Errors::CultivationPlanCropMissingError
    ]
  ).freeze

  WEATHER_PREDICTION_FAILURES = (
    SHARED_PERSISTENCE_FAILURES + [
      Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError,
      Domain::WeatherData::Interactors::WeatherPredictionInteractor::InsufficientPredictionDataError
    ]
  ).freeze

  PLAN_FINALIZE_FAILURES = SHARED_PERSISTENCE_FAILURES.freeze

  TASK_SCHEDULE_TEMPLATE_COMPLETION_FAILURES = SHARED_PERSISTENCE_FAILURES.freeze
end
