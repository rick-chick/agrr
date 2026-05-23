# frozen_string_literal: true

module Adapters
  module CultivationPlan
    class PlanAllocationAdjustInteractorFactory
      def initialize(
        logger:,
        translator:,
        clock:,
        plan_gateway:,
        weather_prediction_gateway:,
        agrr_adjust_gateway:,
        save_adjusted_gateway:,
        optimization_events_gateway:,
        adjust_plan_growth_read_gateway:,
        debug_dump_gateway:
      )
        @logger = logger
        @translator = translator
        @clock = clock
        @plan_gateway = plan_gateway
        @weather_prediction_gateway = weather_prediction_gateway
        @agrr_adjust_gateway = agrr_adjust_gateway
        @save_adjusted_gateway = save_adjusted_gateway
        @optimization_events_gateway = optimization_events_gateway
        @adjust_plan_growth_read_gateway = adjust_plan_growth_read_gateway
        @debug_dump_gateway = debug_dump_gateway
      end

      def build(output_port:)
        Domain::CultivationPlan::Interactors::PlanAllocationAdjustInteractor.new(
          output_port: output_port,
          logger: @logger,
          translator: @translator,
          clock: @clock,
          plan_gateway: @plan_gateway,
          weather_prediction_gateway: @weather_prediction_gateway,
          agrr_adjust_gateway: @agrr_adjust_gateway,
          save_adjusted_gateway: @save_adjusted_gateway,
          optimization_events_gateway: @optimization_events_gateway,
          adjust_plan_growth_read_gateway: @adjust_plan_growth_read_gateway,
          debug_dump_gateway: @debug_dump_gateway
        )
      end
    end
  end
end
