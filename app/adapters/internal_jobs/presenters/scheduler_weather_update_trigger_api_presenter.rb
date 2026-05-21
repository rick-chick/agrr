# frozen_string_literal: true

module Adapters
  module InternalJobs
    module Presenters
      class SchedulerWeatherUpdateTriggerApiPresenter < Domain::InternalJobs::Ports::SchedulerWeatherUpdateTriggerOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success
          @view.render_response(
            json: {
              success: true,
              message: "Weather update jobs enqueued",
              timestamp: Time.current.iso8601
            },
            status: :ok
          )
        end

        def on_failure(failure_dto)
          @view.render_response(
            json: {
              success: false,
              error: failure_dto.message
            },
            status: :internal_server_error
          )
        end
      end
    end
  end
end
