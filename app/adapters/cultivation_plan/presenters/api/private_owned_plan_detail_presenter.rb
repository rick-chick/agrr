# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Presenters
      module Api
        class PrivateOwnedPlanDetailPresenter
          def initialize(view:)
            @view = view
          end

          def on_success(detail)
            @view.render json: {
              id: detail.id,
              name: detail.display_name,
              status: detail.status
            }
          end

          def on_not_found
            @view.render json: { error: "Plan not found" }, status: :not_found
          end

          def on_failure(error_dto)
            @view.render json: { error: error_dto.message }, status: :unprocessable_entity
          end
        end
      end
    end
  end
end
