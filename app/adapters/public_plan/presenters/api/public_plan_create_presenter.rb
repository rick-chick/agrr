# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      module Api
        class PublicPlanCreatePresenter < Domain::PublicPlan::Ports::PublicPlanCreateOutputPort
          def initialize(view:)
            @view = view
          end

          def on_success(success_dto)
            plan_id = success_dto.plan_id

            @view.render_response(
              json: { plan_id: plan_id },
              status: :ok
            )
          end

          def on_failure(failure_dto)
            error_message = failure_dto.respond_to?(:message) ? failure_dto.message : failure_dto.to_s

            # エラーメッセージに基づいて適切なステータスコードを決定
            status = case error_message
            when "Farm not found"
                       :not_found
            when "Invalid farm size", "Invalid total area", "No crops selected"
                       :unprocessable_entity
            when /Failed to create cultivation plan/
                       :internal_server_error
            else
                       # 予期しないエラー（StandardError など）は 500 を返す
                       :internal_server_error
            end

            @view.render_response(
              json: { error: error_message },
              status: status
            )
          end
        end
      end
    end
  end
end
