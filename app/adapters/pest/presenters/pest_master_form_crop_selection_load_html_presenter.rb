# frozen_string_literal: true

module Adapters
  module Pest
    module Presenters
      class PestHtmlCropSelectionLoadHtmlPresenter < Domain::Pest::Ports::PestHtmlCropSelectionLoadOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(bundle)
          @view.instance_variable_set(:@accessible_crops, bundle.accessible_crops)
          @view.instance_variable_set(:@selected_crop_ids, bundle.selected_crop_ids)
          @view.instance_variable_set(:@crop_cards, bundle.crop_cards)
        end
      end
    end
  end
end
