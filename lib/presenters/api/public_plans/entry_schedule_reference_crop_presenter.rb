# frozen_string_literal: true

module Presenters
  module Api
    module PublicPlans
      class EntryScheduleReferenceCropPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(crop)
          @view.instance_variable_set(:@reference_crop, crop)
        end

        def on_failure(error_dto)
          @view.render json: { error: error_dto.message }, status: :not_found
        end
      end
    end
  end
end
