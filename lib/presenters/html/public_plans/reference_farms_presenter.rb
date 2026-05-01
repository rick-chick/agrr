# frozen_string_literal: true

module Presenters
  module Html
    module PublicPlans
      class ReferenceFarmsPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(farms)
          @view.instance_variable_set(:@farms, farms)
        end

        def on_failure(_error_dto = nil)
          @view.instance_variable_set(:@farms, [])
        end
      end
    end
  end
end
