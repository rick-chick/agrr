# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      # POST 保存 API の JSON 応答（成功: { success: true }。失敗は on_failure でエラー JSON）。
      class PublicPlanSaveFromSessionApiApiPresenter < Domain::CultivationPlan::Ports::PublicPlanSaveFromSessionOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(success = nil)
          body = { success: true }
          if success
            body[:cultivation_plan_id] = success.cultivation_plan_id if success.cultivation_plan_id
            body[:plan_reused] = success.plan_reused
          end
          @view.render json: body, status: :ok
        end

        def on_failure(failure)
          dto = Domain::CultivationPlan::Dtos::PublicPlanSaveFailure
          status, error = case failure.kind
          when dto::KIND_MISSING_PLAN_ID
            [ :bad_request, "plan_id is required" ]
          when dto::KIND_PLAN_NOT_FOUND
            [ :not_found, "Plan not found" ]
          when dto::KIND_SAVE_FAILED
            [ :unprocessable_entity, failure.message.presence || "Save failed" ]
          when dto::KIND_UNEXPECTED
            [ :internal_server_error, "Internal server error" ]
          else
            [ :internal_server_error, "Internal server error" ]
          end

          @view.render(
            json: { success: false, error: error },
            status: status
          )
        end
      end
    end
  end
end
