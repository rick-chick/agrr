# frozen_string_literal: true

module Presenters
  module Api
    module Fertilize
      class FertilizeLoadForEditPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(bundle)
          @view.instance_variable_set(:@fertilize, bundle.persisted_fertilize)
        end

        def on_failure
          @view.instance_variable_set(:@fertilize, nil)
        end
      end
    end
  end
end
