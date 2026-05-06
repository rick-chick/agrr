# frozen_string_literal: true

require "test_helper"

module Adapters
  module PublicPlan
    module Gateways
      class PublicPlanOptimizationJobChainActiveRecordGatewayTest < ActiveSupport::TestCase
        test "enqueue_after_create dispatches four jobs with caller_label" do
          dispatcher = mock("dispatcher")
          logger = mock("logger")
          logger.expects(:info).at_least_once
          channel = OptimizationChannel

          weather_location = Struct.new(:latest_weather_date).new(Date.new(2025, 6, 1))
          farm = Struct.new(:id, :latitude, :longitude, :weather_location).new(42, 35.5, 139.5, weather_location)
          plan = Struct.new(:farm).new(farm)

          ::CultivationPlan.stub(:find, proc { |_id| plan }) do
            dispatcher.expects(:enqueue).with do |jobs, **kwargs|
              kwargs[:redirect_path].nil? &&
                kwargs[:caller_label] == "TestCaller" &&
                jobs.size == 4 &&
                jobs[0].is_a?(FetchWeatherDataJob) &&
                jobs[1].is_a?(WeatherPredictionJob) &&
                jobs[2].is_a?(OptimizationJob) &&
                jobs[3].is_a?(TaskScheduleGenerationJob) &&
                jobs[0].farm_id == 42 &&
                jobs[0].cultivation_plan_id == 99 &&
                jobs[0].channel_class == channel &&
                jobs[1].cultivation_plan_id == 99 &&
                jobs[1].channel_class == channel &&
                jobs[2].cultivation_plan_id == 99 &&
                jobs[2].channel_class == channel &&
                jobs[3].cultivation_plan_id == 99 &&
                jobs[3].channel_class == channel
            end

            gateway = PublicPlanOptimizationJobChainActiveRecordGateway.new(
              dispatcher: dispatcher,
              logger: logger,
              channel_class: channel
            )
            gateway.enqueue_after_create!(cultivation_plan_id: 99, caller_label: "TestCaller")
          end
        end

        test "enqueue_after_create passes redirect_path to dispatcher when given" do
          dispatcher = mock("dispatcher")
          logger = mock("logger")
          logger.expects(:info).at_least_once
          channel = OptimizationChannel

          weather_location = Struct.new(:latest_weather_date).new(Date.new(2025, 6, 1))
          farm = Struct.new(:id, :latitude, :longitude, :weather_location).new(42, 35.5, 139.5, weather_location)
          plan = Struct.new(:farm).new(farm)

          ::CultivationPlan.stub(:find, proc { |_id| plan }) do
            dispatcher.expects(:enqueue).with do |jobs, **kwargs|
              kwargs[:redirect_path] == "/results" &&
                kwargs[:caller_label] == "TestCaller" &&
                jobs.size == 4
            end

            gateway = PublicPlanOptimizationJobChainActiveRecordGateway.new(
              dispatcher: dispatcher,
              logger: logger,
              channel_class: channel
            )
            gateway.enqueue_after_create!(
              cultivation_plan_id: 99,
              caller_label: "TestCaller",
              redirect_path: "/results"
            )
          end
        end
      end
    end
  end
end
