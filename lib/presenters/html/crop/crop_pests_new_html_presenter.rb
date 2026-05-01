# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropPestsNewHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(pest:, unassociated_pests:)
          @view.instance_variable_set(:@pest, pest)
          @view.instance_variable_set(:@unassociated_pests, unassociated_pests)
        end
      end
    end
  end
end
