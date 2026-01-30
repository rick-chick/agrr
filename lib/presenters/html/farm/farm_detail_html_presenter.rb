# frozen_string_literal: true

module Presenters
  module Html
    module Farm
      class FarmDetailHtmlPresenter < Domain::Farm::Ports::FarmDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(farm_detail_dto)
          @view.instance_variable_set(:@farm, farm_detail_dto.farm.to_model)
          @view.instance_variable_set(:@fields, farm_detail_dto.fields.map(&:to_model))
          # show テンプレートをレンダリング（暗黙的に）
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.redirect_to @view.farms_path
        end
      end
    end
  end
end