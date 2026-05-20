# frozen_string_literal: true

module Domain
  module InternalJobs
    module Interactors
      class SchedulerWeatherUpdateJobsTriggerInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call
          r = @gateway.enqueue_weather_update_jobs
          case r.kind
          when :success
            @output_port.on_success
          when :failure
            @output_port.on_failure(
              Dtos::SchedulerWeatherUpdateTriggerFailure.new(message: r.error_message)
            )
          else
            raise ArgumentError, "unexpected gateway result kind: #{r.kind.inspect}"
          end
        end
      end
    end
  end
end
