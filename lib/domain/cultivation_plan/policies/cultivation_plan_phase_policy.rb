# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Policies
      # 最適化フェーズ更新の属性と I18n キー（純粋）。メッセージ解決は Interactor の translator。
      module CultivationPlanPhasePolicy
        module_function

        # @return [Hash] :attrs [Hash], :message_key [String, nil], :broadcast [Boolean]
        def build(phase_name:, failure_subphase: nil)
          name = phase_name.to_sym
          case name
          when :start_optimizing
            {
              attrs: {
                status: "optimizing",
                optimization_phase: "initializing"
              },
              message_key: "models.cultivation_plan.phases.initializing",
              broadcast: true
            }
          when :phase_fetching_weather
            phase_attrs("fetching_weather", "models.cultivation_plan.phases.fetching_weather")
          when :phase_weather_data_fetched
            phase_attrs("weather_data_fetched", "models.cultivation_plan.phases.weather_data_fetched")
          when :phase_predicting_weather
            phase_attrs("predicting_weather", "models.cultivation_plan.phases.predicting_weather")
          when :phase_weather_prediction_completed
            phase_attrs("weather_prediction_completed", "models.cultivation_plan.phases.weather_prediction_completed")
          when :phase_optimization_completed
            phase_attrs("optimization_completed", "models.cultivation_plan.phases.optimization_completed")
          when :phase_optimizing
            phase_attrs("optimizing", "models.cultivation_plan.phases.optimizing")
          when :phase_task_schedule_generating
            phase_attrs("task_schedule_generating", "models.cultivation_plan.phases.task_schedule_generating")
          when :phase_completed
            phase_attrs("completed", "models.cultivation_plan.phases.completed")
          when :phase_failed
            key = failure_message_key(failure_subphase)
            {
              attrs: {
                optimization_phase: "failed",
                status: "failed"
              },
              message_key: key,
              broadcast: true
            }
          else
            raise ArgumentError, "Unknown cultivation plan phase: #{phase_name.inspect}"
          end
        end

        def phase_attrs(phase, message_key)
          {
            attrs: { optimization_phase: phase },
            message_key: message_key,
            broadcast: true
          }
        end

        def failure_message_key(failure_subphase)
          case failure_subphase.to_s
          when "fetching_weather"
            "models.cultivation_plan.phase_failed.fetching_weather"
          when "predicting_weather"
            "models.cultivation_plan.phase_failed.predicting_weather"
          when "optimizing"
            "models.cultivation_plan.phase_failed.optimizing"
          when "task_schedule_generation"
            "models.cultivation_plan.phase_failed.task_schedule_generation"
          else
            "models.cultivation_plan.phase_failed.default"
          end
        end
      end
    end
  end
end
