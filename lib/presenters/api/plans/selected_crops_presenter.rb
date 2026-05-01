# frozen_string_literal: true

module Presenters
  module Api
    module Plans
      class SelectedCropsPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(crops)
          @view.instance_variable_set(:@selected_crops, crops)
        end

        def on_failure(error_dto)
          @view.instance_variable_set(:@selected_crops, [])
          @view.instance_variable_set(:@selected_crops_error, error_dto)
        end
      end
    end
  end
end
