# frozen_string_literal: true

module Presenters
  module Api
    module PublicPlan
      # POST 保存 API の JSON 応答（契約: public-plan-save-contract.md）。
      class PublicPlanSaveFromSessionApiPresenter < Domain::CultivationPlan::Ports::PublicPlanSaveFromSessionOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success
          @view.render json: { success: true }, status: :ok
        end

        def on_failure(failure)
          dto = Domain::CultivationPlan::Dtos::PublicPlanSaveFailureDto
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
