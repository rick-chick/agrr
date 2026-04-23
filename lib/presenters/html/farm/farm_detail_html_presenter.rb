# frozen_string_literal: true

module Presenters
  module Html
    module Farm
      class FarmDetailHtmlPresenter < Domain::Farm::Ports::FarmDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(farm_detail_dto)
          farm_gw = Domain::Farm::Gateways::FarmGateway.default
          field_gw = Domain::Field::Gateways::FieldGateway.default
          @view.instance_variable_set(:@farm, farm_gw.find_model(farm_detail_dto.farm.id))
          @view.instance_variable_set(:@fields, farm_detail_dto.fields.map { |fe| field_gw.find_model(fe.id) })
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
