# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropPestsCreateHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def on_already_linked(crop_id:)
          @view.redirect_to @view.crop_pests_path(crop_id), alert: I18n.t("crops.pests.flash.already_associated")
        end

        def on_linked(crop_id:)
          @view.redirect_to @view.crop_pests_path(crop_id), notice: I18n.t("crops.pests.flash.associated")
        end

        def on_link_target_missing(crop_id:)
          @view.redirect_to @view.crop_pests_path(crop_id), alert: I18n.t("crops.pests.flash.not_found")
        end

        def on_reference_only_admin(crop_id:)
          @view.redirect_to @view.crop_pests_path(crop_id), alert: I18n.t("crops.pests.flash.reference_only_admin")
        end

        def on_created(crop_id:, pest_id:)
          @view.redirect_to @view.crop_pest_path(crop_id, pest_id), notice: I18n.t("crops.pests.flash.created")
        end

        def on_invalid(crop_id:, pest_snapshot:, unassociated_pest_entities:)
          @view.instance_variable_set(:@pest, Forms::CropNestedPestForm.from_crop_nest_snapshot(pest_snapshot))
          @view.instance_variable_set(:@unassociated_pests, unassociated_pest_entities)
          @view.render_form(:new, status: :unprocessable_entity)
        end
      end
    end
  end
end
