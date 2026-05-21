# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      class ReferenceCropsPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(crops)
          @view.instance_variable_set(:@crops, crops)
        end

        def on_failure(_error_dto = nil)
          @view.instance_variable_set(:@crops, [])
        end
      end
    end
  end
end
