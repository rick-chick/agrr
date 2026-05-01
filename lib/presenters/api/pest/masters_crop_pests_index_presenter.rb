# frozen_string_literal: true

module Presenters
  module Api
    module Pest
      class MastersCropPestsIndexPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(pests)
          @view.render json: pests
        end
      end
    end
  end
end
