# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropParentAuthorizationFailureApiPresenter
        include Domain::Crop::Ports::CropLoadedAuthorizationFailurePort

        ERROR_BODY = { error: "Crop not found" }.freeze

        def initialize(view:)
          @view = view
        end

        def on_permission_denied
          render_parent_not_found
        end

        def on_not_found
          render_parent_not_found
        end

        private

        def render_parent_not_found
          @view.render json: ERROR_BODY, status: :not_found
        end
      end
    end
  end
end
