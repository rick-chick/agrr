# frozen_string_literal: true

module Presenters
  module Api
    module PublicPlans
      class EntryScheduleReferenceCropsPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(crops)
          @view.instance_variable_set(:@reference_crops, crops)
        end

        def on_failure(error_dto)
          @view.render json: { error: error_dto.message }, status: :internal_server_error
        end
      end
    end
  end
end
