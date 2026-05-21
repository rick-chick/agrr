# frozen_string_literal: true

module Adapters
  module Pesticide
    module Presenters
      class MastersCropPesticidesIndexApiPresenter
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
