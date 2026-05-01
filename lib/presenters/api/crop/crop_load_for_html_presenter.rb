# frozen_string_literal: true

module Presenters
  module Api
    module Crop
      class CropLoadForHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(crop)
          @view.instance_variable_set(:@crop, crop)
        end

        def on_failure
          @view.render json: { error: "Crop not found" }, status: :not_found
        end
      end
    end
  end
end
