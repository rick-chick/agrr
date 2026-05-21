# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropPestsUpdateHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def on_reference_flag_denied(crop_id:, pest_id:)
          @view.redirect_to @view.crop_pest_path(crop_id, pest_id), alert: I18n.t("crops.pests.flash.reference_flag_admin_only")
        end

        def on_updated(crop_id:, pest_id:)
          @view.redirect_to @view.crop_pest_path(crop_id, pest_id), notice: I18n.t("crops.pests.flash.updated")
        end

        def on_not_found(crop_id:)
          @view.redirect_to @view.crop_pests_path(crop_id), alert: I18n.t("crops.pests.flash.not_found")
        end

        def on_invalid(crop_id:, pest_snapshot:)
          @view.instance_variable_set(:@pest, Forms::CropNestedPestForm.from_crop_nest_snapshot(pest_snapshot))
          @view.render_form(:edit, status: :unprocessable_entity)
        end
      end
    end
  end
end
