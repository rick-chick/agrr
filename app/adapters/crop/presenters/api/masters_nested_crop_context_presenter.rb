# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      module Api
        class MastersNestedCropContextPresenter
          def initialize(view:, not_found_message: nil)
            @view = view
            @not_found_message = not_found_message || I18n.t("api.errors.crop_not_found")
          end

          def on_success(crop)
            @view.instance_variable_set(:@crop, crop)
          end

          def on_not_found
            @view.render json: { error: @not_found_message }, status: :not_found
          end
        end
      end
    end
  end
end
