# frozen_string_literal: true

module Presenters
  module Api
    module Pest
      class PestLoadForAiUpdatePresenter
        def initialize(view:)
          @view = view
        end

        def on_success(bundle)
          @view.instance_variable_set(:@pest, bundle.persisted_pest)
        end

        def on_failure(_reason)
          @view.instance_variable_set(:@pest, nil)
        end
      end
    end
  end
end
