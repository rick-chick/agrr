# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropTaskTemplateLoadFailureRedirectHtmlPresenter
        include Domain::Crop::Ports::CropNestedResourceNotFoundFailurePort

        def initialize(view:)
          @view = view
        end

        def on_not_found(crop_id: nil)
          @view.redirect_to @view.crop_agricultural_tasks_path(crop_id), alert: I18n.t("crops.flash.not_found")
        end
      end
    end
  end
end
