# frozen_string_literal: true

module Presenters
  module Api
    module Crop
      class CropListForPlanPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(crops)
          @view.instance_variable_set(:@available_crops, crops)
        end

        def on_failure(_error_dto)
          @view.instance_variable_set(:@available_crops, [])
        end
      end
    end
  end
end
