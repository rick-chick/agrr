# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      module Html
        class CropPestsLoadPestHtmlPresenter
          def initialize(view:)
            @view = view
          end

          def on_success(pest_snapshot)
            @view.instance_variable_set(:@pest, Forms::CropNestedPestForm.from_crop_nest_snapshot(pest_snapshot))
          end

          def on_not_found(crop_id:)
            @view.redirect_to @view.crop_pests_path(crop_id), alert: I18n.t("crops.pests.flash.not_found")
          end
        end
      end
    end
  end
end
