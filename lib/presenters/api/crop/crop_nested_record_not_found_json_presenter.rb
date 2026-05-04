# frozen_string_literal: true

module Presenters
  module Api
    module Crop
      class CropNestedRecordNotFoundJsonPresenter
        include Domain::Crop::Ports::CropNestedJsonNotFoundFailurePort

        def initialize(view:, error_message:)
          @view = view
          @error_message = error_message
        end

        def on_not_found
          @view.render json: { error: @error_message }, status: :not_found
        end
      end
    end
  end
end
