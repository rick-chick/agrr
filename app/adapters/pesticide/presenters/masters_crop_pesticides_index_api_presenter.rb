# frozen_string_literal: true

module Adapters
  module Pesticide
    module Presenters
      class MastersCropPesticidesIndexApiPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(pesticides)
          @view.render json: pesticides
        end

        def on_not_found
          @view.render json: { error: I18n.t("api.errors.crop_not_found") }, status: :not_found
        end
      end
    end
  end
end
