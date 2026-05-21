# frozen_string_literal: true

module Adapters
  module Pest
    module Presenters
      class MastersCropPestsDestroyApiPresenter
        def initialize(view:)
          @view = view
        end

        def on_success
          @view.head :no_content
        end

        def on_crop_not_found
          @view.render json: { error: I18n.t("api.errors.crop_not_found") }, status: :not_found
        end

        def on_pest_not_found
          @view.render json: { error: I18n.t("api.errors.pests.not_found") }, status: :not_found
        end

        def on_not_associated
          @view.render json: { error: I18n.t("api.errors.pests.not_associated") }, status: :not_found
        end

        def on_unexpected(status)
          @view.render json: { error: "Unexpected status: #{status.inspect}" }, status: :internal_server_error
        end
      end
    end
  end
end
