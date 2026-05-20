# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      module Api
        class ReferenceCropsPresenter
          def initialize(view:)
            @view = view
          end

          def on_success(crops)
            @view.render json: crops
          end

          def on_failure(error_dto)
            @view.render json: { error: error_dto.message }, status: :internal_server_error
          end
        end
      end
    end
  end
end
