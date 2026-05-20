# frozen_string_literal: true

module Adapters
  module Backdoor
    module Presenters
      module Api
        class BackdoorClearDatabasePresenter < Domain::Backdoor::Ports::BackdoorClearDatabaseOutputPort
          def initialize(view:)
            @view = view
          end

          def on_success(success_dto)
            @view.render_response(
              json: {
                timestamp: Time.current.iso8601,
                success: true,
                message: "Database cleared successfully",
                before_stats: stats_payload(success_dto.before_stats),
                after_stats: stats_payload(success_dto.after_stats),
                warning: "⚠️ All data has been deleted. This action is irreversible."
              },
              status: :ok
            )
          end

          def on_failure(failure_dto)
            @view.render_response(
              json: {
                timestamp: Time.current.iso8601,
                success: false,
                error: failure_dto.message
              },
              status: :internal_server_error
            )
          end

          private

          def stats_payload(stats)
            {
              users: stats.users,
              farms: stats.farms,
              fields: stats.fields,
              crops: stats.crops,
              cultivation_plans: stats.cultivation_plans
            }
          end
        end
      end
    end
  end
end
