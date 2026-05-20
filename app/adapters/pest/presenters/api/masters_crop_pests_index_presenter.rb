# frozen_string_literal: true

module Adapters
  module Pest
    module Presenters
      module Api
        class MastersCropPestsIndexPresenter
          def initialize(view:)
            @view = view
          end

          def on_success(pests)
            @view.render json: pests.map(&:to_hash)
          end
        end
      end
    end
  end
end
