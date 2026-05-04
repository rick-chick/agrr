# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropPestsUpdateHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def on_reference_flag_denied(crop_id:, pest:)
          @view.redirect_to @view.crop_pest_path(crop_id, pest), alert: I18n.t("crops.pests.flash.reference_flag_admin_only")
        end

        def on_updated(crop_id:, pest:)
          @view.redirect_to @view.crop_pest_path(crop_id, pest), notice: I18n.t("crops.pests.flash.updated")
        end

        def on_invalid(crop_id:, pest:)
          @view.instance_variable_set(:@pest, pest)
          @view.render :edit, status: :unprocessable_entity
        end
      end
    end
  end
end
