# frozen_string_literal: true

module Adapters
  module Pest
    module Presenters
      class MastersCropPestsCreateApiPresenter
        def initialize(view:)
          @view = view
        end

        def on_pest_id_missing
          @view.render json: { error: I18n.t("api.errors.pests.pest_id_required") }, status: :unprocessable_entity
        end

        def on_pest_not_found
          @view.render json: { error: I18n.t("api.errors.pests.not_found") }, status: :not_found
        end

        def on_forbidden
          @view.render json: { error: I18n.t("api.errors.pests.permission_denied") }, status: :forbidden
        end

        def on_already_associated
          @view.render json: { error: I18n.t("api.errors.pests.already_associated") }, status: :unprocessable_entity
        end

        def on_success(crop_id:, pest_id:)
          @view.render json: {
            message: I18n.t("api.messages.pests.associated_successfully"),
            crop_id: crop_id,
            pest_id: pest_id
          }, status: :created
        end
      end
    end
  end
end
