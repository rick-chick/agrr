# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropPestsCreateHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def on_already_linked(crop)
          @view.redirect_to @view.crop_pests_path(crop), alert: I18n.t("crops.pests.flash.already_associated")
        end

        def on_linked(crop)
          @view.redirect_to @view.crop_pests_path(crop), notice: I18n.t("crops.pests.flash.associated")
        end

        def on_link_target_missing(crop)
          @view.redirect_to @view.crop_pests_path(crop), alert: I18n.t("crops.pests.flash.not_found")
        end

        def on_reference_only_admin(crop)
          @view.redirect_to @view.crop_pests_path(crop), alert: I18n.t("crops.pests.flash.reference_only_admin")
        end

        def on_created(crop, pest)
          @view.redirect_to @view.crop_pest_path(crop, pest), notice: I18n.t("crops.pests.flash.created")
        end

        def on_invalid(pest, unassociated_pests)
          @view.instance_variable_set(:@pest, pest)
          @view.instance_variable_set(:@unassociated_pests, unassociated_pests)
          @view.render :new, status: :unprocessable_entity
        end
      end
    end
  end
end
