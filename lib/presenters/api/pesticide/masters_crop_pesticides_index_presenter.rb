# frozen_string_literal: true

module Presenters
  module Api
    module Pesticide
      class MastersCropPesticidesIndexPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(pesticides)
          @view.render json: pesticides
        end
      end
    end
  end
end
