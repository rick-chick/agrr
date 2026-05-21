# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropPestsIndexHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(pests:, available_pests:)
          @view.instance_variable_set(:@pests, pests)
          @view.instance_variable_set(:@available_pests, available_pests)
          @view.render template: "crops/pests/index", formats: [:html]
        end
      end
    end
  end
end
