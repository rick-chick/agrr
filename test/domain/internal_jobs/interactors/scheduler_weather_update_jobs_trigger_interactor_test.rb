# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module InternalJobs
    module Interactors
      class SchedulerWeatherUpdateJobsTriggerInteractorTest < DomainLibTestCase
        setup do
          @gateway = mock("weather_update_jobs_enqueue_gateway")
          @presenter = mock("presenter")
          @interactor = SchedulerWeatherUpdateJobsTriggerInteractor.new(
            output_port: @presenter,
            gateway: @gateway
          )
        end

        test "success calls on_success" do
          @gateway.expects(:enqueue_weather_update_jobs).returns(
            Gateways::WeatherUpdateJobsEnqueueGateway::EnqueueWeatherUpdateJobsResult.success
          )
          @presenter.expects(:on_success)

          @interactor.call
        end

        test "failure maps message to failure dto" do
          @gateway.expects(:enqueue_weather_update_jobs).returns(
            Gateways::WeatherUpdateJobsEnqueueGateway::EnqueueWeatherUpdateJobsResult.failure("enqueue failed")
          )
          @presenter.expects(:on_failure).with do |dto|
            dto.is_a?(Dtos::SchedulerWeatherUpdateTriggerFailure) && dto.message == "enqueue failed"
          end

          @interactor.call
        end
      end
    end
  end
end
