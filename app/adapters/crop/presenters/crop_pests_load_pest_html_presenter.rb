# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropPestsLoadPestHtmlPresenter
        include Adapters::Shared::Presenters::HtmlDisplaySupport

        def initialize(view:)
          @view = view
        end

        def on_success(pest_snapshot, html_display: nil)
          @view.instance_variable_set(:@pest, Forms::CropNestedPestForm.from_crop_nest_snapshot(pest_snapshot))
          assign_html_display(@view, html_display) if html_display
        end

        def on_not_found(crop_id:)
          @view.redirect_to @view.crop_pests_path(crop_id), alert: I18n.t("crops.pests.flash.not_found")
        end
      end
    end
  end
end
