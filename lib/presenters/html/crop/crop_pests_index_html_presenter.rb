# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropPestsIndexHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(pests:, available_pests:)
          @view.instance_variable_set(:@pests, pests)
          @view.instance_variable_set(:@available_pests, available_pests)
        end
      end
    end
  end
end
